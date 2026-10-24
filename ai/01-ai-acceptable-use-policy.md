# 1. AI Acceptable Use Policy

**Company:** [Company Name] | **Owner:** [Name, role] | **Version:** 1.3 | **Effective:** [date] | **Review:** every 6 months

## Purpose
This policy defines the organisation’s approved use of AI tools, model services and AI agents. It applies to Microsoft 365 Copilot, GitHub Copilot, approved model APIs, AI-enabled software and internal or vendor-developed AI systems used for business work.

The organisation will use AI to improve productivity, support business workflows and accelerate software delivery while protecting confidential information, operational integrity, legal obligations and customer trust.

## Scope
This policy applies to all employees, contractors, consultants, partner staff and developers who use or develop AI systems on the organisation’s behalf, whether using company-issued devices, approved work accounts or approved cloud services.

It covers:

- Microsoft 365 Copilot and related Microsoft 365 productivity features
- GitHub Copilot and approved AI-assisted coding tools
- approved enterprise or business-tier model services and APIs
- AI agents, copilots, automations and workflows
- AI-enabled SaaS, browser tools, plugins, connectors and integrations

## Approved business use
AI use is permitted only when it supports an approved business purpose and meets the organisation’s governance, privacy and security requirements. Approved use includes:

- Microsoft 365 Copilot for approved user groups and business scenarios
- GitHub Copilot for approved software development tasks
- approved model services used for defined and reviewed use cases
- AI agents and workflows with named owners and documented controls

The following are not approved for company data unless formally authorised in writing:

- personal or consumer AI accounts
- unreviewed browser extensions or AI plugins
- unapproved third-party connectors or community MCP servers
- tools without adequate privacy, retention, residency or security controls
- AI use that bypasses identity, logging, approval or data-handling controls

Any new AI tool, model or agent must be reviewed and approved by [owner] before use in business processes.

## Data classification and permitted use
Data must be classified before it is entered into any AI tool. Where there is uncertainty, the rule is simple: do not enter it.

| Data class | Examples | Allowed AI use |
| --- | --- | --- |
| Never | passwords, secrets, API keys, payroll, regulated personal data, legal-privileged material, unreleased IP, embedded credentials in source code | Not permitted in any AI tool |
| Restricted | contracts, customer records, internal financials, HR records, operational data, non-public project details | Only approved tools with explicit controls and human review |
| General | public information, non-sensitive drafts, routine internal notes | Approved tools only |

No user may paste, upload or attach Restricted or Never data to an unapproved AI tool or to a system without documented controls and a business-approved use case.

## Prohibited conduct
The following are prohibited:

- processing sensitive business data in unapproved AI tools
- using personal AI accounts for company work
- entering secrets, API keys, access tokens, credentials or private keys into prompts or code generation tools
- relying on AI-generated decisions in legal, medical, HR, recruitment, credit, compliance or safety-sensitive decisions without human review
- bypassing security controls, DLP, logging, approval or access restrictions
- using AI tools to move data beyond approved boundaries or to avoid review processes
- publishing or acting on AI-generated content without validation, approval and factual review

## Human accountability
- Users remain responsible for all AI-assisted content they input, approve, share, publish or act upon.
- AI output must be checked for accuracy, privacy impact, business correctness and operational safety before use.
- AI supports human work; it does not replace accountability.
- If disclosure is required by a client, regulator or policy, that requirement must still be met.

## AI agent and automation requirements
Any AI agent or automation used for business purposes must meet the following minimum conditions:

- named business owner and technical owner
- defined purpose and approved business use case
- dedicated identity; not a personal account or shared admin account
- least-privilege access only to required systems, files and APIs
- human approval before irreversible actions such as sending external email, deleting data, modifying permissions, altering customer records, making payments or publishing externally
- logging of prompts, actions, failures and outputs
- kill switch, rate limits and regular owner review
- registration in the AI inventory before production use

Agents that consume external content, email, websites, uploaded files or user-generated content must be treated as high risk and must not directly send data externally without an approval layer and a human checkpoint.

## Security and monitoring
- MFA or passkeys are required for all AI user and admin accounts.
- AI tool and agent activity may be monitored for security, compliance and operational assurance.
- Users must not disable logging, bypass controls, jailbreak prompts, connect unapproved apps or use unauthorised plugins.
- Secrets must not be embedded in prompts, agent instructions, code repositories, configuration files or operational documentation.
- Where supported, AI chat history, agent memory and tool traces must be retained only for the approved business purpose and reviewed according to the organisation’s policy.

## AI development and coding rules
For developers and technical teams:

- GitHub Copilot and similar AI coding tools may be used only for approved engineering work
- do not paste secrets, credentials, customer data or proprietary code with embedded sensitive values into prompts
- validate generated code, dependencies, vulnerabilities, licensing and operational impact before merge or deployment
- do not deploy AI-generated infrastructure or application changes without review, testing and sign-off
- any AI-assisted code that interacts with production systems must follow secure coding and change-control requirements

## Incident reporting
Report immediately to [contact] if any of the following occur:

- restricted or confidential data was entered into an unapproved AI tool
- an AI agent acted unexpectedly, accessed unauthorised systems, sent data incorrectly or triggered an unsafe action
- an AI tool, plugin or connector exposed data or bypassed controls
- prompt injection, malicious instructions or unusual external input were observed
- a secret, token or credential was exposed via AI prompts, code generation or system output

Good-faith reporting will not be penalised.

## Exceptions and enforcement
Any exception to this policy requires written approval from [owner], must be recorded with a business justification, risk assessment and review date, and must include compensating controls.

Violations may result in restricted access, loss of AI privileges, disciplinary action or other corrective actions.

## Sign-off and acknowledgement
I understand this policy and agree to use AI in a manner consistent with the organisation’s approved tools, data rules and security controls.

**Name:** [Name] | **Title:** [Title] | **Signature:** [Signature] | **Date:** [Date]

**Approved by:** [Approver Name] | **Role:** [Role] | **Date:** [Date]
