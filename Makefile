SHELL := /bin/sh

.PHONY: help test package docker-build clean

help:
	@echo "Targets: help, test, package, docker-build, clean"

test:
	@echo "[test] Creating sample files..."
	@rm -rf .tmp-test && mkdir -p .tmp-test/sub
	@printf 'one\n' > .tmp-test/a.log
	@printf 'two\n' > .tmp-test/sub/b.log
	@printf 'ignore\n' > .tmp-test/c.txt
	@echo "[test] Running POSIX script (no encryption)..."
	@./GraveDigger.sh -t log -o test-logs -r .tmp-test
	@ls -l test-logs.tar.gz || true
	@echo "[test] Running PowerShell script (no encryption)..."
	@pwsh -NoLogo -NoProfile -File ./GraveDigger.ps1 -Extension log -Output test-logs-ps -Root .tmp-test || echo "PowerShell not available; skipping"
	@ls -l test-logs-ps.zip || true

package:
	@echo "[package] Creating release tarball..."
	@tar -czf gravedigger-release.tar.gz README.md LICENSE GraveDigger.sh GraveDigger.ps1 rules_list.list || true
	@ls -l gravedigger-release.tar.gz

docker-build:
	@docker build -t gravedigger:latest .

clean:
	@rm -rf .tmp-test test-logs.tar.gz test-logs-ps.zip gravedigger-release.tar.gz
