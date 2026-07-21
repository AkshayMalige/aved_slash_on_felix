# ##################################################################################################
#  The MIT License (MIT)
#  Copyright (c) 2025 Advanced Micro Devices, Inc. All rights reserved.
# 
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
#  and associated documentation files (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish, distribute,
#  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
# 
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ##################################################################################################

DOXYFILE = Doxyfile
DOC_DIR = ./docs
HTML_DIR = $(DOC_DIR)/html
LATEX_DIR = $(DOC_DIR)/latex
PDF_OUTPUT = $(DOC_DIR)/vrt-doc.pdf

all: html pdf

html:
	@echo "Generating HTML documentation..."
	doxygen $(DOXYFILE)
	@echo "HTML documentation generated in $(HTML_DIR)"
	@echo "Open $(HTML_DIR)/index.html to view documentation"

pdf: html
	@echo "Generating PDF documentation..."
	cd $(LATEX_DIR) && make
	@if [ -f "$(LATEX_DIR)/refman.pdf" ]; then \
		cp $(LATEX_DIR)/refman.pdf $(PDF_OUTPUT); \
		echo "PDF documentation generated: $(PDF_OUTPUT)"; \
	else \
		echo "Failed to generate PDF"; \
	fi

clean:
	@echo "Cleaning up documentation..."
	rm -rf $(DOC_DIR)
	@echo "Documentation removed"

rebuild: clean all

help:
	@echo "Doxygen Documentation Generation for VRT"
	@echo ""
	@echo "Available targets:"
	@echo "  all     - Generate both HTML and PDF documentation (default)"
	@echo "  html    - Generate HTML documentation only"
	@echo "  pdf     - Generate PDF documentation (requires LaTeX)"
	@echo "  clean   - Remove all generated documentation"
	@echo "  rebuild - Clean and regenerate all documentation"
	@echo "  help    - Display this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make            - Generate all documentation"
	@echo "  make html       - Generate HTML only"
	@echo "  make clean      - Remove documentation"
	@echo "  make rebuild    - Clean and rebuild all documentation"

.PHONY: all html pdf clean rebuild help