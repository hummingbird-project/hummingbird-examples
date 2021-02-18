# HTTP2 example

Example demonstrating the setup of a HTTP2 upgrade. 

The HTTP2 upgrade is done via TLS so for this to work you need to supply valid certificate chain and private key PEM files for your site. 
```
swift run hummingbird-http2 --certificate-chain cert.pem --private-key privkey.pem
```
