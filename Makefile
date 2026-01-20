.PHONY: install
install:
	find . -name "*.lua" -type f | while read file; do \
		rel_path=$$(echo "$$file" | sed 's|^\./||'); \
		dest_dir="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/$$(dirname "$$rel_path")"; \
		mkdir -p "$$dest_dir"; \
		cp "$$file" "$$dest_dir/"; \
	done