import os
import sys
import yaml

def merge_yaml_rules(input_dir, output_file):
    """
    Combines individual rule files into a single YAML file with a top-level 'rules' tag.
    """
    combined_rules = []
    
    # Check if input directory exists
    if not os.path.isdir(input_dir):
        print(f"Error: The directory '{input_dir}' does not exist.")
        sys.exit(1)
        
    print(f"Scanning directory '{input_dir}' for YAML files...")
    
    # Iterate through all files in the directory
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith(('.yaml', '.yml')):
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = yaml.safe_load(f)
                    
                    # Ensure the file data is not empty
                    if not data:
                        continue
                        
                    # Case 1: The input file already contains a top-level 'rules' list
                    if isinstance(data, dict) and 'rules' in data:
                        if isinstance(data['rules'], list):
                            combined_rules.extend(data['rules'])
                        else:
                            print(f"Warning: 'rules' key in {file} is not a list. Skipping.")
                            
                    # Case 2: The input file is written as a list directly
                    elif isinstance(data, list):
                        combined_rules.extend(data)
                        
                    # Case 3: The input file contains a single rule dictionary
                    elif isinstance(data, dict):
                        combined_rules.append(data)
                        
                except Exception as e:
                    print(f"Error reading file {file}: {e}")

    # Prepare final output structure
    output_data = {'rules': combined_rules}
    
    # Write the combined rules to the output file
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            # sort_keys=False preserves the structural layout of your keys (e.g., id first)
            yaml.dump(output_data, f, sort_keys=False, allow_unicode=True, default_flow_style=False)
        print(f"Successfully merged {len(combined_rules)} rules into '{output_file}'.")
    except Exception as e:
        print(f"Error writing output file: {e}")

if __name__ == "__main__":
    # You can change these paths as needed
    INPUT_DIRECTORY = "./" 
    OUTPUT_FILENAME = "semgrep-experimental.yaml"
    
    merge_yaml_rules(INPUT_DIRECTORY, OUTPUT_FILENAME)
