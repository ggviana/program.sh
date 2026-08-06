lint:
	shellcheck -x install.sh uninstall.sh bin/* lib/* tests/* $$(find examples -name '*.sh' 2>/dev/null)

fmt:
	shfmt -w bin lib examples tests

fmt-check:
	shfmt -l bin lib examples tests

test:
	bats tests
