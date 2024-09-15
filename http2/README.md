# HTTP2 example

Example demonstrating the setup of a HTTP2 upgrade. 

The HTTP2 upgrade is done via TLS so for this to work you need to supply valid certificate chain and private key PEM files for your site. The example comes with a script that will generate a CA certificate, server certificate and private key. You can use these to run the example. 

Run `./scripts/generate-certs.sh`. This will create all the require files in a `resources/certs` folder in the root of the example. If running in Xcode set the working directory for your the project to be the root folder.

```sh
swift run App
```

To test the sample you can use `curl`. You need to provide the root trust certificate that the server certificate and key were generated from.

```sh
curl --cacert resources/certs/ca.crt https://localhost:8081/http
```

### Implementation Notes

The most important line needed to enable HTTP2 is the following:

```swift
server: .http2Upgrade(tlsConfiguration: arguments.tlsConfiguration),
```

It's located in `Application+build.swift`, and requires a `TLSConfiguration` to be passed in. This configuration is created in `app.swift` .