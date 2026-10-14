# Security Policy

Please do not open a public issue for security problems.

Report them privately through GitHub:
**Security → Report a vulnerability** on this repository
(https://github.com/FvorY/pdf-signature-sdk-ios/security/advisories/new).

You can expect a first reply within 7 days. Fixes are released as a new patch version
and noted in `CHANGELOG.md`.

This SDK does not send any data over the network on its own. It only downloads a PDF when
the host app passes a remote URL, and it never logs or stores document passwords.
