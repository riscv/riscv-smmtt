# Resolve cross-page links (<<Zkl-notation.adoc#id>>, xref:Zkl-notation.adoc#id[])
# inside the assembled PDF.
#
# The chapters live in modules/ROOT/pages/ and are Antora pages, where a link to
# another chapter must name that chapter's file. Asciidoctor treats such a link
# as internal only when the file is one it included, and it records includes by
# the path written in src/Zkl.adoc (../modules/ROOT/pages/Zkl-notation). This
# also registers each included page under its file name, so the links resolve
# to their anchors and get the usual text ("Section 1").
#
# SPDX-License-Identifier: CC-BY-SA-4.0

require 'asciidoctor/extensions'

Asciidoctor::Extensions.register do
  tree_processor do
    process do |doc|
      includes = doc.catalog[:includes]
      includes.keys.each {|path| includes[File.basename path] = true }
      nil
    end
  end
end
