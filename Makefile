# Version comes from __version__ in mokuro-cbz; override with VERSION=x.y.z
VERSION ?= $(shell sed -n 's/^__version__ = "\(.*\)"$$/\1/p' mokuro-cbz)

# nfpm installed by install-deps; nfpm from PATH is used if there is one
NFPM_VERSION ?= v2.47.0
GO_BIN = $(or $(shell go env GOBIN 2>/dev/null),$(shell go env GOPATH 2>/dev/null)/bin)
NFPM ?= $(or $(shell command -v nfpm 2>/dev/null),$(GO_BIN)/nfpm)

.PHONY: packages deb rpm install-deps clean
packages: deb rpm

deb rpm:
	@test -n "$(VERSION)" || { echo "no __version__ found in mokuro-cbz" >&2; exit 1; }
	mkdir -p build
	VERSION=$(VERSION) $(NFPM) package -p $@ -t build/

install-deps:
	@command -v go >/dev/null || { echo "go missing: install Go first, e.g. apt install golang-go" >&2; exit 1; }
	go install github.com/goreleaser/nfpm/v2/cmd/nfpm@$(NFPM_VERSION)

clean:
	rm -rf build
