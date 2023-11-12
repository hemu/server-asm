.intel_syntax noprefix
.globl _start

.section .text

# file descriptor locations
# rbx -- listening socket
# r12 -- client connection socket

#STDOUT equ 1

# Search header and parse content length
fn_find_content_length:
    mov rax, 0 # i
    mov r13, OFFSET request # haystack
    reset_needle:
        mov r14, OFFSET content_length_literal  # needle
    # cmp 16 bytes 
    compare_string:
        mov rcx, 0
        mov cl, BYTE PTR [r13] 
        mov rdx, 0

        mov dl, BYTE PTR [r14]
        cmp cl, dl
        je char_equal
        jmp char_not_equal
      
    char_equal:
        cmp cl, 58 # if current character is colon, we are done
        je done
        inc r13
        inc r14
        jmp compare_string

    char_not_equal:
        cmp rax, 20 # check max iterations as safety bounds
        je done
        inc r13
        jmp reset_needle

    done:
        # increment two more times to align pointer with start digit
        mov rax, r13
        inc rax
        inc rax
        ret


# @param/rax: memory address of first digit
# @ret/rax: parsed integer
# @ret/rdx: pointer to first non digit char after integer
fn_parse_integer:
    mov rsi, rax # points to start digit
    mov rcx, 0 # clear out rcx just in case since we will use cl
    mov rdx, 0 # clear out rdx just in case since we will use dl
    mov rax, 0
    start_parse_integer_loop:
        mov dl, BYTE PTR [rsi] 
        # --- check character digit bounds ---
        mov cl, 48
        cmp dl, cl

        jl done_parse_integer_loop

        mov cl, 57
        cmp dl, cl
        jg done_parse_integer_loop 
        # ---------------------------------
        sub dl, 48  # convert char into digit
        imul rax, 10
        add rax, rdx
        inc rsi
        jmp start_parse_integer_loop
    done_parse_integer_loop:

        # final integer will be in rax already
        mov rdx, rsi
        ret


# expects 1 parameters on stack in this order
# @param/rcx: fd for file
# @param/rax: content length
# @param/rdx: pointer to first char after content length
fn_write_content:
    mov rsi, rdx
    add rsi, 4 # offset for \r\n\r\n before content starts
    mov rdx, rax

    mov rax, 1
    mov rdi, rcx
    # rdx already holds content length
    syscall
    ret


fn_write_response_status_line:
    # write()
    # write http response to socket
    mov rax, 1
    mov rdi, r12

    mov rsi, OFFSET status_line
    mov rdx, 19
    syscall
    ret


fn_find_request_type:
    # parse request
    mov r13, OFFSET request
    mov al, [r13]
    cmp al, 71
    je is_get_request
    is_post_request:
        mov rax, 1
        ret
    is_get_request:
        mov rax, 0
        ret


# accept()
# block until we receive an incoming connection on socket
accept_connection:
    mov rax, 43
    mov rdi, rbx
    mov rsi, 0

    mov rdx, 0
    syscall
    mov r12, rax

    # fork()
    # split off processing connection so we can accept more
    # connections while doing I/O
    mov rax, 57
    syscall
    cmp rax, 0

    je handle_request 
    # PID returned by fork syscall is NOT 0, so this is parent process, so
    # go back to accepting more connections
    # close incoming socket for parent connection (since child will take care of it)

    mov rax, 3
    mov rdi, r12
    syscall
    jmp accept_connection


handle_request:
    # read()
    # read http request from socket
    mov rax, 0
    mov rdi, r12
    mov rsi, OFFSET request
    mov rdx, 512
    syscall

    # parse request
    mov r13, OFFSET request
find_slash:
    mov al, [r13]
    cmp al, 47
    je done_find_slash
    inc r13
    jmp find_slash
done_find_slash:
    mov r14, r13
    mov r15, OFFSET file_path
iterate_find_space:
    mov al, [r14]
    cmp al, 32

    je terminate_file_path
    mov al, [r14]
    mov BYTE PTR [r15], al # copy file path to memory as we go
    inc r15
    inc r14
    jmp iterate_find_space
# add null byte to terminate file path string
terminate_file_path:
    mov DWORD PTR [r15], 0
    call fn_find_request_type
    cmp rax, 1
    je handle_POST_request

# Assuming GET request since no jump -- fall through to handling GET request
handle_GET_REQUEST:
    # open file specified in file path
    mov rax, 2
    mov rdi, OFFSET file_path
    mov rsi, 0 # O_RDONLY	
    mov rdx, 0
    syscall
    
    # read file
    mov rdi, rax
    mov rax, 0
    mov rsi, OFFSET file

    mov rdx, 512
    syscall
    mov r15, rax # number of bytes read from file

    # close file
    mov rax, 3
    syscall

    # write response
    call fn_write_response_status_line 

    mov rax, 1
    mov rdi, r12
    mov rsi, OFFSET file
    mov rdx, r15

    syscall
    jmp exit


handle_POST_request:
    call fn_find_content_length
    call fn_parse_integer
    mov r13, rax # content length
    mov r14, rdx # pointer to after content length
    
    # open file specified in file path
    mov rax, 2
    mov rdi, OFFSET file_path
    mov rsi, 65 # O_WRONLY | O_CREAT
    mov rdx, 511 # mode 0777
    syscall

    mov rcx, rax
    mov rax, r13
    mov rdx, r14
    call fn_write_content

    # close file
    mov rax, 3
    syscall

    call fn_write_response_status_line
    jmp exit
exit:
    mov rax, 0x3C
    mov rdi, 0
    syscall


_start:
    # socket()
    # create a socket
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    syscall

    # bind()
    # try to claim port with socket
    mov rbx, rax
    mov rdi, rbx
    mov rax, 49
    mov rsi, OFFSET sockaddrin
    mov rdx, 16
    syscall

    # listen()
    # declare we want to listen for incoming connections on socket
    mov rax, 50
    mov rdi, rbx
    mov rsi, 0
    syscall

    jmp accept_connection


.section .data
sockaddrin:
    .short 2
    .short 0xB90B # PORT: This is 3001 in hex but **BIG ENDIAN**
    .byte 0, 0, 0, 0 # localhost

status_line:
    # status line
    .byte 72, 84, 84, 80, 47, 49, 46, 48, 32, 50, 48, 48, 32, 79, 75
    # \r\n\r\n
    .byte 13, 10, 13, 10

request:
    .space 512

file_path:
    .space 256

file:
    .space 512

content_length_literal:
    .asciz "Content-Length:"

