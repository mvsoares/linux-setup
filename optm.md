# Ansible Setup Optimization Plan

## Objective
Implement optimizations and improvements to the Ansible workstation setup, focusing on better package management, improved error handling, syntax modernization, and more robust module usage.

## Scope & Impact
These changes refine how the Ansible setup executes without changing the final installed state of the system.
- **`ansible/roles/repos/tasks/main.yml`**: Refactor Debian/Ubuntu repository additions.
- **`ansible/roles/packages/tasks/main.yml`**: Handle system packages more robustly.
- **`ansible/roles/shell/tasks/main.yml`**: Optimize file modifications.
- **Global**: Modernize boolean syntax (`yes`/`no` -> `true`/`false`) and replace `failed_when: false` with appropriate error handling or modules.

## Proposed Solution

### Phase 1: Modernize Debian/Ubuntu Repository Management
- **Target:** `ansible/roles/repos/tasks/main.yml`
- **Actions:**
  - Replace `get_url` + `curl | gpg` shell combinations with the modern `ansible.builtin.deb822_repository` module to handle GPG keys and repo setup seamlessly.
  - Refactor `add-apt-repository` shell tasks to use the native `ansible.builtin.apt_repository` module.

### Phase 2: Refine Error Handling (Removing `failed_when: false`)
- **Target:** All role tasks (e.g., `shell`, `tweaks`, `languages`, `editors`).
- **Actions:**
  - Locate all instances of `failed_when: false`.
  - Replace binary existence checks (like `which starship`) with `ansible.builtin.stat` or use `ignore_errors: true` combined with `register` for optional steps.
  - Remove blanket suppression of failures, making playbook execution safer and more transparent.

### Phase 3: Optimize Task Modules & Idempotency
- **Target:** `ansible/roles/shell/tasks/main.yml`
- **Actions:**
  - Consolidate multiple `ansible.builtin.lineinfile` operations that modify `.bashrc` into a single `ansible.builtin.blockinfile` task, ensuring a cleaner configuration and faster execution.

### Phase 4: Improve Package Installation Resilience
- **Target:** `ansible/roles/packages/tasks/main.yml`
- **Actions:**
  - Currently, `_pkg_list` merges all packages into one giant transaction. Refactor the installation to loop over package categories (e.g., essentials, network, developer). This prevents the entire setup from failing if a single non-essential package name is incorrect.

### Phase 5: Ansible Syntax Modernization
- **Target:** `ansible/**/*.yml`, `ansible/ansible.cfg`
- **Actions:**
  - Replace all legacy YAML booleans (`yes`/`no`) with standard `true`/`false`.
  - Update `ansible.cfg`: Ensure `fact_caching_connection` points to a more standard location like `/var/cache/ansible-facts` or clarify its behavior when running under `become: true`.

## Verification & Testing
- Run syntax check: `ansible-playbook ansible/main.yml --syntax-check`
- Lint the project: `ansible-lint ansible/`
- Execute a dry-run to ensure changes are idempotent: `ansible-playbook ansible/main.yml --check --diff`