import Hummingbird
import SotoS3

extension HBApplication {
    public struct AWS {
        public var client: AWSClient {
            get { self.application.extensions.get(\.aws.client) }
            nonmutating set {
                application.extensions.set(\.aws.client, value: newValue) { client in
                    // shutdown AWSClient
                    try client.syncShutdown()
                }
            }
        }

        let application: HBApplication
    }

    public var aws: AWS { return .init(application: self) }
}
