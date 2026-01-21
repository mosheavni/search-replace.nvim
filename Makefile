.PHONY: all lint test prepare clean docs

all: test


lint:
	stylua --check lua/
	luacheck lua/ --globals vim

test: prepare
	nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests { minimal_init = './tests/minimal_init.vim' }"

prepare:
	@test -d ../plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ../plenary.nvim
	@command -v stylua >/dev/null || { \
		curl -L -o stylua.zip https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip && \
		unzip stylua.zip && \
		rm -f stylua.zip && \
		chmod +x stylua && \
		sudo mv stylua /usr/local/bin/; \
	}

clean:
	rm -rf ../plenary.nvim

docs:
	@command -v lemmy-help >/dev/null || { \
		echo "Installing lemmy-help..."; \
		curl -Lq https://github.com/numToStr/lemmy-help/releases/latest/download/lemmy-help-$$(uname -m | sed 's/arm64/aarch64/')-apple-darwin.tar.gz | tar xz; \
		chmod +x lemmy-help; \
		sudo mv lemmy-help /usr/local/bin/; \
	}
	lemmy-help -c \
		lua/search-replace/init.lua \
		lua/search-replace/core.lua \
		> doc/search-replace.txt
