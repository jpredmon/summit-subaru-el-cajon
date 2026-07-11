import 'package:web/web.dart' as web;

/// Web implementation: sets the actual browser tab title.
void setDocumentTitle(String title) {
  web.document.title = title;
}
