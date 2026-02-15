#!/usr/bin/env python3
"""
Fix ansible-lint and yamllint violations across all roles.

This script:
1. Renames generic role_* variables to role-prefixed variables
2. Fixes handler name casing (restart role services -> Restart {role} services)
3. Changes shell -> command where no shell features needed
4. Fixes line length issues in verify.yml
5. Adds missing document start markers
"""

import os
import re
from pathlib import Path

ROLES_DIR = Path("/Users/kellycaylor/dev/rcd-cui/roles")

# Variables to rename (generic -> role-prefixed)
GENERIC_VARS = [
    "role_packages",
    "role_templates",
    "role_files",
    "role_services",
    "role_verify_commands",
    "role_evidence_files",
    "role_evidence_commands",
]


def get_role_name(role_path: Path) -> str:
    """Extract role name from path."""
    return role_path.name


def fix_defaults_main(role_path: Path, role_name: str) -> bool:
    """Rename generic variables to role-prefixed in defaults/main.yml."""
    defaults_file = role_path / "defaults" / "main.yml"
    if not defaults_file.exists():
        return False

    content = defaults_file.read_text()
    modified = False

    for var in GENERIC_VARS:
        prefixed_var = f"{role_name}_{var.replace('role_', '')}"
        if var in content:
            content = content.replace(var, prefixed_var)
            modified = True

    if modified:
        defaults_file.write_text(content)
        print(f"  Fixed defaults/main.yml")

    return modified


def fix_tasks_main(role_path: Path, role_name: str) -> bool:
    """Fix variable references and notify handlers in tasks/main.yml."""
    tasks_file = role_path / "tasks" / "main.yml"
    if not tasks_file.exists():
        return False

    content = tasks_file.read_text()
    modified = False

    # Rename variable references
    for var in GENERIC_VARS:
        prefixed_var = f"{role_name}_{var.replace('role_', '')}"
        if var in content:
            content = content.replace(var, prefixed_var)
            modified = True

    # Fix notify handler reference
    old_notify = "notify: restart role services"
    new_notify = f"notify: Restart {role_name} services"
    if old_notify in content:
        content = content.replace(old_notify, new_notify)
        modified = True

    if modified:
        tasks_file.write_text(content)
        print(f"  Fixed tasks/main.yml")

    return modified


def fix_tasks_verify(role_path: Path, role_name: str) -> bool:
    """Fix variable references, shell->command, and line length in tasks/verify.yml."""
    verify_file = role_path / "tasks" / "verify.yml"
    if not verify_file.exists():
        return False

    content = verify_file.read_text()
    modified = False

    # Rename variable references
    for var in GENERIC_VARS:
        prefixed_var = f"{role_name}_{var.replace('role_', '')}"
        if var in content:
            content = content.replace(var, prefixed_var)
            modified = True

    # Fix shell -> command (verification commands are simple)
    if "ansible.builtin.shell:" in content:
        content = content.replace("ansible.builtin.shell:", "ansible.builtin.command:")
        modified = True

    # Fix line length issue - break the compliant calculation
    # Find the long line pattern and reformat
    long_line_pattern = r'compliant: "\{\{ \(.*?\| length\) \}\}"'

    # Use a simpler approach - replace the specific long line pattern
    old_compliant = f'compliant: "{{{{ ({role_name}_verify_results.results | default([]) | selectattr(\'rc\', \'equalto\', 0) | list | length) == ({role_name}_verify_commands | length) }}}}"'

    # Multi-line version with intermediate variable approach
    # Actually, let's just use a shorter version that's still clear
    new_compliant = f'''compliant: >-
        {{{{ ({role_name}_verify_results.results | default([]) |
        selectattr('rc', 'equalto', 0) | list | length) ==
        ({role_name}_verify_commands | length) }}}}'''

    if old_compliant in content:
        content = content.replace(old_compliant, new_compliant)
        modified = True
    else:
        # Try the original pattern with role_verify_commands
        old_generic = 'compliant: "{{ (ROLENAME_verify_results.results | default([]) | selectattr(\'rc\', \'equalto\', 0) | list | length) == (ROLENAME_verify_commands | length) }}"'
        old_generic = old_generic.replace('ROLENAME', role_name)
        if old_generic in content:
            content = content.replace(old_generic, new_compliant)
            modified = True

    if modified:
        verify_file.write_text(content)
        print(f"  Fixed tasks/verify.yml")

    return modified


def fix_tasks_evidence(role_path: Path, role_name: str) -> bool:
    """Fix variable references and shell->command in tasks/evidence.yml."""
    evidence_file = role_path / "tasks" / "evidence.yml"
    if not evidence_file.exists():
        return False

    content = evidence_file.read_text()
    modified = False

    # Rename variable references
    for var in GENERIC_VARS:
        prefixed_var = f"{role_name}_{var.replace('role_', '')}"
        if var in content:
            content = content.replace(var, prefixed_var)
            modified = True

    # Fix shell -> command
    if "ansible.builtin.shell:" in content:
        content = content.replace("ansible.builtin.shell:", "ansible.builtin.command:")
        modified = True

    if modified:
        evidence_file.write_text(content)
        print(f"  Fixed tasks/evidence.yml")

    return modified


def fix_handlers_main(role_path: Path, role_name: str) -> bool:
    """Fix handler name casing and variable references in handlers/main.yml."""
    handlers_file = role_path / "handlers" / "main.yml"
    if not handlers_file.exists():
        return False

    content = handlers_file.read_text()
    modified = False

    # Rename variable references
    for var in GENERIC_VARS:
        prefixed_var = f"{role_name}_{var.replace('role_', '')}"
        if var in content:
            content = content.replace(var, prefixed_var)
            modified = True

    # Fix handler name (lowercase -> Uppercase)
    old_handler_name = "- name: restart role services"
    new_handler_name = f"- name: Restart {role_name} services"
    if old_handler_name in content:
        content = content.replace(old_handler_name, new_handler_name)
        modified = True

    # Fix listen directive
    old_listen = "listen: restart role services"
    new_listen = f"listen: Restart {role_name} services"
    if old_listen in content:
        content = content.replace(old_listen, new_listen)
        modified = True

    if modified:
        handlers_file.write_text(content)
        print(f"  Fixed handlers/main.yml")

    return modified


def fix_role(role_path: Path) -> None:
    """Apply all fixes to a single role."""
    role_name = get_role_name(role_path)

    # Skip common role - it has different structure
    if role_name == "common":
        print(f"Skipping common role (different structure)")
        return

    print(f"\nProcessing role: {role_name}")

    fix_defaults_main(role_path, role_name)
    fix_tasks_main(role_path, role_name)
    fix_tasks_verify(role_path, role_name)
    fix_tasks_evidence(role_path, role_name)
    fix_handlers_main(role_path, role_name)


def fix_inventory_hosts() -> None:
    """Add missing document start to inventory/hosts.yml."""
    hosts_file = Path("/Users/kellycaylor/dev/rcd-cui/inventory/hosts.yml")
    if hosts_file.exists():
        content = hosts_file.read_text()
        if not content.startswith("---"):
            content = "---\n" + content
            hosts_file.write_text(content)
            print("\nFixed inventory/hosts.yml - added document start")


def fix_control_mapping() -> None:
    """Fix control_mapping.yml YAML formatting."""
    import yaml

    mapping_file = Path("/Users/kellycaylor/dev/rcd-cui/roles/common/vars/control_mapping.yml")
    if not mapping_file.exists():
        print("\ncontrol_mapping.yml not found")
        return

    try:
        content = mapping_file.read_text()
        data = yaml.safe_load(content)

        # Rewrite with proper formatting
        with open(mapping_file, 'w') as f:
            f.write("---\n")
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True, indent=2)

        print("\nFixed control_mapping.yml - reformatted YAML")
    except Exception as e:
        print(f"\nError fixing control_mapping.yml: {e}")


def main():
    """Main entry point."""
    print("Fixing ansible-lint and yamllint violations...")
    print("=" * 60)

    # Fix all roles
    for role_path in sorted(ROLES_DIR.iterdir()):
        if role_path.is_dir():
            fix_role(role_path)

    # Fix inventory
    fix_inventory_hosts()

    # Fix control_mapping.yml
    fix_control_mapping()

    print("\n" + "=" * 60)
    print("Done! Run 'make ee-lint' and 'make ee-yamllint' to verify.")


if __name__ == "__main__":
    main()
