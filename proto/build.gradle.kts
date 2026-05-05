plugins {
    id("com.google.protobuf") version "0.9.4"
    `java-library`
}

apply(plugin = "org.jetbrains.kotlin.jvm")

dependencies {
    api("io.grpc:grpc-protobuf:1.68.1")
    api("io.grpc:grpc-stub:1.68.1")
    api("com.google.protobuf:protobuf-java:3.25.5")

    // For javax.annotation.Generated used by generated stubs on JDK 9+
    api("javax.annotation:javax.annotation-api:1.3.2")
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:3.25.5"
    }
    plugins {
        create("grpc") {
            artifact = "io.grpc:protoc-gen-grpc-java:1.68.1"
        }
    }
    generateProtoTasks {
        all().forEach { task ->
            task.plugins {
                create("grpc")
            }
        }
    }
}

sourceSets {
    main {
        java {
            srcDirs(
                "build/generated/source/proto/main/java",
                "build/generated/source/proto/main/grpc",
            )
        }
    }
}
