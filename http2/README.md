# HTTP2 example

Example demonstrating the setup of a HTTP2 upgrade. 

The HTTP2 upgrade is done via TLS so for this to work you need to supply valid certificate chain and private key PEM files for your site. The example comes with a script that will generate a CA certificate, server certificate and private key. You can use these to run the example. 

Run `./scripts/generate-certs.sh`. This wil create all the require files in a certs folder in the root of the example. If running in Xcode set the working directory for your the project to be the root folder.  

The sample requires you provide the paths to the various certificates
```
swift run Server --certificate-chain certs/server.crt --private-key certs/server.key
```

To test the sample you can use `curl`. You need to provide the root trust certificate that the server certificate and key were generated from.
```
curl --cacert certs/ca.crt https://localhost:8080/http
```
