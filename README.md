HTTP server written in assembly.

Runs on localhost:3001

- Handles multiple requests async
- It can only handle very contrived requests:
    - GET request to fetch a file on disk
    - POST request to append to a file (with hardcoded expected format in request)

To build:
```bash
make
```

run (will also build):
```
./run
```

See `test/` directory for sending test GET and POST requests

TODO:
- when sever is started, display a message indicating that it is running on localhost:3001
- get read/write to tests/ directory working. Right now only works for read/write to directories like /tmp
- figure out why POST request writes unnecessary bytes to file
