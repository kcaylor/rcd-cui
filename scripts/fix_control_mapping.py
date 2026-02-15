#!/usr/bin/env python3
"""
Fix control_mapping.yml YAML indentation to comply with yamllint.

The issue is that PyYAML's default dump doesn't indent list items under keys.
We need:
  controls:
    - control_id: 3.1.1
Not:
  controls:
  - control_id: 3.1.1
"""

import yaml
from pathlib import Path


class IndentedDumper(yaml.SafeDumper):
    """Custom YAML dumper that indents list items properly."""
    pass


def str_representer(dumper, data):
    """Represent multi-line strings with literal block style."""
    if '\n' in data:
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)


def increase_indent(self, flow=False, indentless=False):
    """Override to force list item indentation."""
    return super(IndentedDumper, self).increase_indent(flow, False)


IndentedDumper.add_representer(str, str_representer)
IndentedDumper.increase_indent = increase_indent


def fix_control_mapping():
    """Fix control_mapping.yml indentation."""
    mapping_file = Path("/Users/kellycaylor/dev/rcd-cui/roles/common/vars/control_mapping.yml")

    if not mapping_file.exists():
        print("control_mapping.yml not found")
        return

    # Load the data
    content = mapping_file.read_text()
    data = yaml.safe_load(content)

    # Write with proper indentation
    with open(mapping_file, 'w') as f:
        f.write("---\n")
        yaml.dump(
            data,
            f,
            Dumper=IndentedDumper,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            indent=2,
            width=120
        )

    print("Fixed control_mapping.yml indentation")


if __name__ == "__main__":
    fix_control_mapping()
