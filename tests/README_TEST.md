# How to test

Send HTTP requests to localhost. This currently only accepts 2 very specific requests for small content lengths:

1.) GET request accessing a file path
2.) POST request accessing a file path with contents that should be written

EXAMPLES:

```bash
./send test_get_request.txt
```

-- GET REQUEST --
GET /tmp/jello.txt HTTP/1.1\r\nHost: localhost\r\nUser-Agent: python-requests/2.31.0\r\nAccept-Encoding: gzip, deflate, zstd\r\nAccept: */*\r\nConnection: keep-alive\r\n\r\n

-- GET RESPONSE --
HTTP/1.0 200 OK

<file contents of tmp/jello.txt>


```bash
./send test_post_request.txt
```

-- POST REQUEST --
POST /tmp/jello.txt HTTP/1.1\r\nHost: localhost\r\nUser-Agent: python-requests/2.31.0\r\nAccept-Encoding: gzip, deflate, zstd\r\nAccept: */*\r\nConnection: keep-alive\r\nContent-Length: 198\r\n\r\nR316WO7DuEP9EO5sQYukEdCrKdYxSCxetKM3fXw33hGBDFUYz8LGppGoZYRfTHPQoCagiLKg1

-- POST RESPONSE --
HTTP/1.0 200 OK

--> tmp/jello_write.txt should have been updated with specified content:
"R316WO7DuEP9EO5sQYukEdCrKdYxSCxetKM3fXw33hGBDFUYz8LGppGoZYRfTHPQoCagiLKg1"
