// Checks Apple's signed App Store data (StoreKit 2 transactions and App Store Server Notifications V2): a JWS whose
// header carries the certificate chain (x5c). The chain must end in Apple Root CA - G3, each certificate must be
// signed by the next one, the leaf must be Apple's App Store receipt signer, and the JWS must be signed by the leaf.
// Transactions made in Xcode's local StoreKit testing are signed by a local certificate: they are accepted only when
// the secret APPLE_ALLOW_XCODE is "1" (the local copy for testing; never set it on the live project).
import 'npm:reflect-metadata@0.2.2';
import * as x509 from 'npm:@peculiar/x509@1.12.3';
import { compactVerify, importX509 } from 'npm:jose@5.9.6';

/** Apple Root CA - G3 (https://www.apple.com/certificateauthority/), SHA-256 63:34:3A:BF:…:91:79. */
const APPLE_ROOT_G3 = 'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==';
/** OIDs Apple puts in the App Store signing certificates (leaf) and the WWDR intermediate. */
const LEAF_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

const b64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const pem = (der: string) => `-----BEGIN CERTIFICATE-----\n${der.match(/.{1,64}/g)!.join('\n')}\n-----END CERTIFICATE-----`;

export class AppleSignatureError extends Error {}

/** The JWS payload when it is really from Apple (or from Xcode testing, when allowed). */
export async function verifyApple<T>(jws: string, allowXcode = false): Promise<T> {
  const [head, body] = jws.split('.');
  if (!head || !body) throw new AppleSignatureError('not a JWS');
  const part = (s: string) => {
    try {
      return JSON.parse(new TextDecoder().decode(b64(s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '='))));
    } catch {
      throw new AppleSignatureError('not readable');
    }
  };
  const header = part(head);
  const chain: string[] = header.x5c ?? [];
  if (header.alg !== 'ES256' || chain.length < 1) throw new AppleSignatureError('header');
  const payload = part(body);
  const env = payload.environment ?? payload.data?.environment;
  const xcode = env === 'Xcode' || env === 'LocalTesting';

  if (!(xcode && allowXcode)) {
    if (chain.length !== 3) throw new AppleSignatureError('chain length');
    const certs = chain.map((c) => new x509.X509Certificate(b64(c)));
    const root = new x509.X509Certificate(b64(APPLE_ROOT_G3));
    if (!certs[2].equal(root)) throw new AppleSignatureError('not Apple root');
    const now = new Date();
    for (const c of certs) if (c.notBefore > now || c.notAfter < now) throw new AppleSignatureError('expired certificate');
    if (!(await certs[0].verify({ publicKey: certs[1].publicKey, signatureOnly: true }))) throw new AppleSignatureError('leaf signature');
    if (!(await certs[1].verify({ publicKey: certs[2].publicKey, signatureOnly: true }))) throw new AppleSignatureError('intermediate signature');
    if (!certs[0].getExtension(LEAF_OID)) throw new AppleSignatureError('leaf is not the App Store signer');
    if (!certs[1].getExtension(INTERMEDIATE_OID)) throw new AppleSignatureError('intermediate is not Apple WWDR');
  }
  const key = await importX509(pem(chain[0]), 'ES256');
  await compactVerify(jws, key).catch(() => { throw new AppleSignatureError('JWS signature'); });
  return payload as T;
}
