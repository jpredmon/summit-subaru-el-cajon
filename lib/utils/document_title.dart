import 'document_title_stub.dart' if (dart.library.html) 'document_title_web.dart' as impl;

/// Sets the browser tab title on web; no-op on native platforms (resolved at
/// compile time via conditional import, so native builds never pull in
/// `dart:html`). SRP/VDP call this with [dealerNameProvider]/`vdpPageTitle`
/// output to mirror the web app's `useDocumentTitle`.
void setDocumentTitle(String title) => impl.setDocumentTitle(title);
