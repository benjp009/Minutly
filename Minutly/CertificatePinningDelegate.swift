//
//  CertificatePinningDelegate.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation
import Security

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedDomains: [String: [Data]]

    init(pinnedDomains: [String: [Data]]) {
        self.pinnedDomains = pinnedDomains
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Get the hostname
        let hostname = challenge.protectionSpace.host

        // Check if we have pinned certificates for this domain
        guard let pinnedCertificates = pinnedDomains[hostname] else {
            // No pinning configured for this domain, use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify the certificate chain using modern API
        var error: CFError?
        let evaluationResult = SecTrustEvaluateWithError(serverTrust, &error)

        guard evaluationResult else {
            if let error = error {
                print("❌ Certificate evaluation failed for \(hostname): \(error.localizedDescription)")
            } else {
                print("❌ Certificate evaluation failed for \(hostname)")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check if any certificate in the chain matches our pinned certificates
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            print("❌ Failed to retrieve certificate chain for \(hostname)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for certificate in certificateChain {

            let certificateData = SecCertificateCopyData(certificate) as Data

            if pinnedCertificates.contains(certificateData) {
                print("✅ Certificate pinning successful for \(hostname)")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // No matching certificate found
        print("❌ Certificate pinning failed for \(hostname) - no matching pinned certificate")
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

// MARK: - URLSession Extension

extension URLSession {
    static func createPinnedSession(with delegate: CertificatePinningDelegate) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}
