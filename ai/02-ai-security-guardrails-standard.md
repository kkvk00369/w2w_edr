# 2. AI Security Guardrails Standard

**Company:** [Company Name] | **Owner:** [Name, role] | **Version:** 1.3 | **Effective:** [date] | **Review:** every 6 months

## Purpose
This standard defines the minimum security and governance controls required before AI tools, model-driven features and AI agents may be used within the business. It applies to Microsoft 365 Copilot, GitHub Copilot, model APIs, AI-enabled software, internal AI development and custom agentic workflows.

The objective is to reduce risk from data leakage, prompt injection, insecure automation, over-privileged access, poor model oversight and uncontrolled AI adoption while maintaining operational value.

## Scope
This standard applies to all approved AI use, including user-facing productivity tools, developer tools, custom agents, automation workflows and third-party AI-enabled services used by the business.

## Mandatory control domains

### 1. Governance and approval
Every AI system in use must have:

- a named owner and business sponsor
- a documented purpose and approved use case
- a record of data classification and approved data boundaries
- review and approval before go-live
- ongoing monitoring and periodic review after deployment

No AI tool or agent may be used for business work without a known owner and an approval record.

### 2. Identity and access management
- Only company-managed or approved enterprise identities may be used.
- MFA or passkeys are required for all AI users and administrators.
- AI agent identities must use dedicated service principals or managed identities, not personal user accounts or shared admin accounts.
- Access must be least privilege and reviewed regularly.
- OAuth consent, enterprise app registrations and API permissions must be reviewed at least monthly.
- Privileged access for AI systems must be time-bound, justified and revoked when no longer required.

### 3. Data protection and handling
- Data must be classified before being used in prompts, uploaded files or model APIs.
- Restricted and Never data must not be sent to unapproved tools or AI services.
- Business-critical or sensitive data must only be used with approved enterprise features and documented boundaries.
- Broad sharing in SharePoint, OneDrive and Teams must be reviewed and reduced where required.
- Secrets, certificates, tokens, passwords and customer credentials must not be included in prompts, scripts, repository content or agent instructions.
- For approved tools, retention settings, audit logging and data deletion controls must be confirmed before use.

### 4. AI usage boundaries
The following rules apply:

- AI may support drafting, summarising, searching, coding or routine productivity tasks only when the use case is approved.
- AI output is not authoritative and must be validated before use or publishing.
- Employment, recruitment, credit, pricing, legal, health or compliance decisions must remain under human control.
- AI must not be used to evade controls, bypass DLP, conceal data access or generate content that is later published or acted on without review.

### 5. Prompt injection and untrusted content controls
Any external content or user-provided content must be treated as untrusted. This includes:

- email content
- uploaded files
- website content
- chat messages
- customer submissions
- third-party API responses

Minimum controls include:

- treating AI input as untrusted and validating outputs before use
- separating reading external content from sending or acting on data externally
- validating tool calls and data flows before allowing external actions
- preventing agents from autonomously publishing external content without an approval step
- testing for prompt injection, prompt-bypass and malicious instruction scenarios before production use

### 6. AI agent development controls
Any custom AI agent or automation system must meet minimum engineering controls:

- named owner and business purpose
- approved architecture and model selection
- code review and change control before deployment
- secret management through a secure secret store, not in prompts or source code
- separate development, test and production environments
- logging of prompts, tool calls, outputs, failures and permission use
- version review of models and integrations before rollout
- kill switch, rate limits and safe fallback conditions
- explicit approval for irreversible actions

Custom AI agents must not be released into production until their risks are reviewed and a documented rollback or shutdown path exists.

### 7. Tool and connector governance
- AI integrations must use only approved models, applications and connectors.
- Community plugins, third-party MCP servers and unvetted integrations are not approved for business data.
- Connector permissions must be limited to the minimum required.
- Access to SaaS connectors, mailboxes, files, databases and APIs must be reviewed before implementation.
- New connectors and agent tools must be risk assessed before they are enabled for employee use.

### 8. Monitoring, logging and incident response
The organisation must maintain:

- AI usage logs for approved tools and agents
- audit logs for model access, agent activity and permission changes
- alerts for unusual AI usage patterns, app-consent activity, privilege changes and data exfiltration indicators
- a documented process for reporting and investigating AI security incidents
- a response plan to disable tools, revoke access and review token or agent exposure

Any suspected leak, malicious input, accidental disclosure or unexpected automation behaviour must be reported immediately.

### 9. Secure AI development lifecycle
For internal AI and agent development, the minimum lifecycle is:

1. business case and owner approval
2. data classification and threat review
3. model, tool and architecture review
4. secure code and prompt review
5. secret and identity review
6. security testing for prompt injection, misuse and data leakage
7. limited pilot deployment
8. sign-off for production use
9. continuous review and periodic control validation

### 10. Exceptions and compliance
Exceptions must be documented, approved by [owner], time-bound and supported by compensating controls. Exceptions must not override prohibited data handling rules, legal obligations or contractual restrictions.

## Acceptance criteria for go-live
A tool or agent may be approved for production only when all of the following are true:

- named owner and documented purpose
- business need and data classification are defined
- approved tool and model selection is confirmed
- identity and access are least privilege and protected
- secrets and credentials are managed securely
- logs, monitoring and incident reporting are in place
- prompt injection and misuse tests are complete
- human approval controls exist for irreversible actions
- approval record is signed by business and security ownership

## Review and maintenance
This standard must be reviewed at least every six months and after any material change to AI use, model deployment, connectors, agent architecture or business process.

**Approved by:** [Name] | [Role] | [Date]
