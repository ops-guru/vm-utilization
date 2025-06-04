# Security Guidelines

This document outlines security best practices for the VM Utilization Agent project.

## 🔒 Security Principles

### Never Commit Sensitive Data

**NEVER commit any of the following to the repository:**

- ❌ SSH private keys (`id_rsa`, `id_ed25519`, etc.)
- ❌ SSH public keys (unless they are example/template keys)
- ❌ AWS access keys or secret keys
- ❌ Azure subscription IDs or service principal credentials
- ❌ Passwords in plain text
- ❌ API tokens or authentication keys
- ❌ Certificate files (`.pem`, `.p12`, `.pfx`)
- ❌ Terraform state files or `.tfvars` files with real values

### Use Placeholder Values Only

All documentation and example code should use placeholder values:

✅ **Good:**
```bash
--access-key "<YOUR_AWS_ACCESS_KEY>"
--secret-key "<YOUR_AWS_SECRET_KEY>"
ssh_public_key = "<YOUR_SSH_PUBLIC_KEY>"
```

❌ **Bad:**
```bash
--access-key "AKIAIOSFODNN7EXAMPLE"
--secret-key "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
```

## 🛡 Secure Development Practices

### 1. Environment Variables

Store sensitive data in environment variables, not in code:

```bash
export AWS_ACCESS_KEY_ID="your-key-here"
export AWS_SECRET_ACCESS_KEY="your-secret-here"
```

### 2. Configuration Files

Use separate configuration files that are gitignored:

```bash
# Create config file (gitignored)
echo "aws_access_key_id = your-key" > .secrets
echo ".secrets" >> .gitignore
```

### 3. Terraform Best Practices

- Use separate `.tfvars` files for different environments
- Store `.tfvars` files outside the repository
- Use environment variables for sensitive values:
  ```bash
  export TF_VAR_admin_password="YourSecurePassword"
  terraform apply
  ```

### 4. AWS Credentials

Store AWS credentials using AWS CLI or IAM roles:

```bash
# Configure AWS CLI (credentials stored in ~/.aws/)
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

## 🔍 Security Review Checklist

Before committing code, verify:

- [ ] No hardcoded passwords or secrets
- [ ] No real SSH keys included
- [ ] No AWS/Azure credentials exposed
- [ ] All examples use placeholder values
- [ ] `.gitignore` is comprehensive and up-to-date
- [ ] Sensitive files are properly excluded

## 🚨 Security Incident Response

If sensitive data is accidentally committed:

### 1. Immediate Actions

```bash
# Remove the sensitive file
git rm --cached sensitive-file.txt

# Commit the removal
git commit -m "Remove sensitive file"

# Force push (if safe to do so)
git push --force
```

### 2. GitHub Actions

- Change any exposed credentials immediately
- Rotate SSH keys if exposed
- Review GitHub security alerts
- Consider making the repository private temporarily

### 3. Long-term Actions

- Review and improve security practices
- Update documentation and training
- Consider using tools like `git-secrets` to prevent future incidents

## 🔧 Recommended Tools

### Git Hooks

Set up pre-commit hooks to scan for secrets:

```bash
# Install git-secrets
brew install git-secrets  # macOS
# or
sudo apt-get install git-secrets  # Ubuntu

# Configure git-secrets
git secrets --register-aws
git secrets --install
```

### IDE Extensions

- **VS Code**: GitLens, SonarLint
- **IntelliJ**: SonarLint plugin
- **General**: EditorConfig for consistent formatting

## 📝 Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. Email the maintainers directly
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be addressed before public disclosure

## 📚 Additional Resources

- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
- [Azure Security Documentation](https://docs.microsoft.com/en-us/azure/security/)
- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)

---

**Remember: Security is everyone's responsibility. When in doubt, ask for a security review.** 