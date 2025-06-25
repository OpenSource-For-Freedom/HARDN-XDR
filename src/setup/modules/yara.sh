#################################### YARA
HARDN_STATUS "error" "Setting up YARA rules..."

# Check if YARA command exists (implies installation)
if ! command -v yara >/dev/null 2>&1; then
	HARDN_STATUS "warning" "Warning: YARA command not found. Skipping rule setup."
   

else
	HARDN_STATUS "pass" "YARA command found."
	HARDN_STATUS "info" "Creating YARA rules directory..."
	mkdir -p /etc/yara/rules
	chmod 755 /etc/yara/rules # Ensure directory is accessible

	HARDN_STATUS "info" "Checking for git..."
	if ! command -v git >/dev/null 2>&1; then
		HARDN_STATUS "info" "git not found. Attempting to install..."
		if apt-get update >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1; then
			HARDN_STATUS "pass" "git installed successfully."
		else
			HARDN_STATUS "error" "Error: Failed to install git. Cannot download YARA rules."
			return 1 # Exit this section
		fi
	else
		HARDN_STATUS "pass" "git command found."
	fi

	local rules_repo_url="https://github.com/Yara-Rules/rules.git"
	local temp_dir
	temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

	if [[ ! -d "$temp_dir" ]]; then
		HARDN_STATUS "error" "Error: Failed to create temporary directory for YARA rules."
		return 1 # Exit this section
	fi

	HARDN_STATUS "info" "Cloning YARA rules from $rules_repo_url to $temp_dir..."
	if git clone --depth 1 "$rules_repo_url" "$temp_dir" >/dev/null 2>&1; then
		HARDN_STATUS "pass" "YARA rules cloned successfully."

		HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
		local copied_count=0
		# Find all .yar files in the cloned repo and copy them
		while IFS= read -r -d $'\0' yar_file; do
			if cp "$yar_file" /etc/yara/rules/; then
				((copied_count++))
			else
				HARDN_STATUS "warning" "Warning: Failed to copy rule file: $yar_file"
			fi
		done < <(find "$temp_dir" -name "*.yar" -print0)

		if [[ "$copied_count" -gt 0 ]]; then
			HARDN_STATUS "pass" "Copied $copied_count YARA rule files to /etc/yara/rules/."
		else
			 HARDN_STATUS "warning" "Warning: No .yar files found or copied from the repository."
		fi

	else
		HARDN_STATUS "error" "Error: Failed to clone YARA rules repository."
	fi

	HARDN_STATUS "info" "Cleaning up temporary directory $temp_dir..."
	rm -rf "$temp_dir"
	HARDN_STATUS "pass" "Cleanup complete."

	HARDN_STATUS "pass" "YARA rules setup attempt completed."
fi


