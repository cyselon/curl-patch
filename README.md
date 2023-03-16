Curl Patch
==================
a patch to enable HTTP2 and JA3 fingerprint to be configurable for CURL

## install 

1 download binary and extract to somewhere
2 set env so that you program can use it

Assume you extract curl-path file to /opt/curl

For Linux
```shell
export LD_LIBRARY_PATH=/opt/curl/lib:$LD_LIBRARY_PATH
```

for macos
```shell
export DYLD_LIBRARY_PATH=/opt/curl/lib:$DYLD_LIBRARY_PATH
```
