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
	@command -v vimcats >/dev/null || { \
		echo "Installing vimcats via cargo..."; \
		command -v cargo >/dev/null || { echo "Error: cargo not found. Install Rust: https://rustup.rs"; exit 1; }; \
		cargo install vimcats --features=cli; \
		command -v asdf >/dev/null && asdf reshim rust || true; \
	}
	vimcats -c -f \
		lua/search-replace/init.lua \
		lua/search-replace/core.lua \
		> doc/search-replace.txt
