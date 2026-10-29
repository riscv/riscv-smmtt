# Makefile for RISC-V Doc Template
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# This Makefile is designed to automate the process of building and packaging
# the Doc Template for RISC-V Extensions.

DOCS := \
	supervisor-domains.adoc

# Spec short name used in ARC-compliant PDF filenames.
SPEC_SHORT := supervisor-domains

DATE ?= $(shell date +%Y-%m-%d)
DATE_STAMP := $(subst -,,$(DATE))
VERSION ?= $(shell ./scripts/release-info.sh version)
VERSION_NUM := $(patsubst v%,%,$(VERSION))

# .docmode ("spec" default | "doc") -- see scripts/release-info.sh. "doc" is
# for non-ratified documentation repos (e.g. docs-dev-guide): it keeps the PDF
# and HTML targets but strips the ratification/phase surface below.
DOC_MODE ?= $(shell ./scripts/release-info.sh mode)

PHASE ?= $(shell ./scripts/release-info.sh phase "$(VERSION)")
PHASE_DISPLAY ?= $(shell ./scripts/release-info.sh display "$(VERSION)")
PHASE_NOTICE ?= $(shell ./scripts/release-info.sh notice "$(VERSION)")
REVMARK ?= $(shell ./scripts/release-info.sh revremark "$(VERSION)")
MILESTONE_ID ?= $(PHASE)

# In spec mode, pass the phase/milestone attributes through to asciidoctor so
# spec-sample.adoc's Document State preface and the title-page revremark
# render. In doc mode those are empty (see release-info.sh's neutralization),
# so instead pass a single doc-mode marker attribute: spec-sample.adoc and
# index.adoc key their ifdef::doc-mode[]/ifndef::doc-mode[] guards off its
# PRESENCE, not a blank value, which is what lets them drop those sections
# entirely rather than rendering them empty.
ifeq ($(DOC_MODE),doc)
	PHASE_OPTS := -a doc-mode='doc'
else
	PHASE_OPTS := -a phase='${PHASE}' \
	              -a phase_display='${PHASE_DISPLAY}' \
	              -a phase_notice='${PHASE_NOTICE}' \
	              -a milestone_id='${MILESTONE_ID}' \
	              -a revremark='${REVMARK}'
endif
DOCKER_IMG := ghcr.io/riscv/riscv-docs-base-container-image:latest
DOCKER_BIN ?= docker
ifneq ($(SKIP_DOCKER),true)
	DOCKER_IS_PODMAN = \
		$(shell ! ${DOCKER_BIN} -v 2>&1 | grep podman >/dev/null ; echo $$?)
	ifeq "$(DOCKER_IS_PODMAN)" "1"
		DOCKER_VOL_SUFFIX = :z
	endif

	DOCKER_CMD := \
		${DOCKER_BIN} run --rm \
			-v ${PWD}:/build${DOCKER_VOL_SUFFIX} \
			-w /build \
			${DOCKER_IMG} \
			/bin/sh -c
	DOCKER_QUOTE := "
endif

BUILD_DIR := build

DOCS_PDF := $(DOCS:%.adoc=%.pdf)
DOCS_HTML := $(DOCS:%.adoc=%.html)

XTRA_ADOC_OPTS :=
ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor
OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a revnumber=${VERSION} \
           -a revdate=${DATE} \
           $(PHASE_OPTS) \
           -a spec_short='${SPEC_SHORT}' \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-style=docs-resources/themes/riscv-pdf.yml \
           $(XTRA_ADOC_OPTS) \
		   -D build \
           --failure-level=ERROR
REQUIRES := --require=asciidoctor-bibtex \
            --require=asciidoctor-diagram \
            --require=asciidoctor-mathematical

DOCS_RESOURCES_CONFIG := docs-resources/global-config.adoc

.PHONY: all build clean build-container build-no-container build-docs check-docs-resources

all: build

check-docs-resources:
	@if [ ! -f "$(DOCS_RESOURCES_CONFIG)" ]; then \
		echo "Notice: docs-resources submodule is missing or uninitialized."; \
		if command -v git >/dev/null 2>&1 && [ -d .git ]; then \
			echo "Automatically initializing git submodules..."; \
			git submodule update --init --recursive || { \
				echo "ERROR: Failed to update git submodules automatically."; \
				echo "Please run manually: git submodule update --init --recursive"; \
				exit 1; \
			}; \
		else \
			echo "ERROR: Missing docs-resources directory and git is unavailable."; \
			echo "Please clone submodules or run: git submodule update --init --recursive"; \
			exit 1; \
		fi; \
	fi

build-docs: check-docs-resources $(DOCS_PDF) $(DOCS_HTML)

# ARC-compliant PDF name: <basename>-v<version>-<YYYYMMDD>.pdf, so every build
# (local or CI) emits a uniquely identifiable artifact.
ARC_PDF = $(1)-v$(VERSION_NUM)-$(DATE_STAMP).pdf

# ...but only a build off a clean vX.YY -- a tag, or an explicit VERSION= as CI
# passes -- is actually SUBMITTABLE. An untagged build resolves VERSION to
# <latest>-<sha> (release-info.sh), so its filename carries the sha and is a dev
# artifact. Report that honestly rather than asserting compliance it lacks.
ARC_EXACT := $(if $(findstring -,$(VERSION)),,yes)

# AsciiDoctor writes the ARC name itself (-o is resolved relative to -D), rather
# than the build renaming build/<basename>.pdf afterwards. Inside the container
# build/ is created by root, so a host-side `mv` into it fails with EPERM on
# rootful Docker -- which is exactly how v0.61 shipped a non-compliant
# build/spec-sample.pdf while the log claimed the ARC name. Naming it at the
# source removes the failure mode instead of reporting it.
%.pdf: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) -o $(call ARC_PDF,$*) $< $(DOCKER_QUOTE)
	@test -f build/$(call ARC_PDF,$*) || { echo "ERROR: build/$(call ARC_PDF,$*) was not produced" >&2; exit 1; }
	@if [ "$(DOC_MODE)" = "doc" ]; then \
		echo "PDF: build/$(call ARC_PDF,$*)"; \
	elif [ -n "$(ARC_EXACT)" ]; then \
		echo "ARC submission PDF: build/$(call ARC_PDF,$*)"; \
	else \
		echo "Development PDF: build/$(call ARC_PDF,$*)"; \
		echo "  Built from an untagged commit ($(VERSION)) -- NOT an ARC submission artifact."; \
		echo "  Build from a v* tag, or run 'make VERSION=vX.YY', to produce one."; \
	fi

%.html: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

build:
	@echo "Checking if Docker is available..."
	@if command -v ${DOCKER_BIN} >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

# Update docker image to latest
docker-pull-latest:
	${DOCKER_BIN} pull ${DOCKER_IMG}

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
