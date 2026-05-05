# W3 Docker Apple Silicon build fix

## Symptom

```txt
rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2
--grpc_out: protoc-gen-grpc: Plugin killed by signal 5.
```

## Cause

The Docker build was running an amd64 protobuf/grpc codegen binary on an Alpine-based image. Alpine does not provide the glibc loader path expected by the amd64 binary, so protoc plugin execution fails under Rosetta/QEMU.

## Fix

Use Debian/Ubuntu based Temurin images for the builder and runtime:

- `eclipse-temurin:21-jdk-jammy`
- `eclipse-temurin:21-jre-jammy`

This keeps the Gradle/protobuf generation path compatible with linux/amd64 image builds on Apple Silicon.
