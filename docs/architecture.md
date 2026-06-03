# GCP Landing Zone — Detailed Architecture

## End-to-End Platform View

```mermaid
flowchart TB
    classDef mgmt fill:#e8f4fd,stroke:#1a73e8
    classDef sec fill:#fce8e6,stroke:#d93025
    classDef net fill:#e6f4ea,stroke:#188038
    classDef log fill:#fef7e0,stroke:#f9ab00
    classDef wl fill:#f3e8fd,stroke:#9334e6

    USER["Users · CI/CD · On-Prem"] --> IDP["Identity<br/>Cloud Identity · WIF"]

    IDP --> ORG["Organization"]

    ORG --> MGMT["Management<br/>Org · Billing · IAM"]:::mgmt
    ORG --> SEC["Security<br/>SCC · KMS · VPC-SC"]:::sec
    ORG --> NET["Networking<br/>NCC · Shared VPC · DNS"]:::net
    ORG --> LOG["Logging<br/>Archive · Monitoring"]:::log
    ORG --> WL["Workloads<br/>Prod · NonProd · Sandbox"]:::wl

    MGMT --> OP["Org Policies"]
    MGMT --> TAGS["Tags / Labels"]

    SEC --> SCC["SCC Premium"]
    SEC --> KMS["Cloud KMS"]
    SEC --> VPCSC["VPC Service Controls"]

    NET --> NCC["NCC Hub"]
    NET --> SVPC["Shared VPC"]
    NET --> EGRESS["Egress · NAT · Armor"]

    LOG --> SINKS["Org Log Sinks"]
    LOG --> MON["Monitoring & Alerting"]

    WL --> GKE["GKE"]
    WL --> RUN["Cloud Run"]
    WL --> GCE["Compute Engine"]
    WL --> DATA["Cloud SQL · Spanner · BigQuery"]

    NCC --> WL
    SVPC --> WL
    SINKS --> GCS["GCS Log Archive"]
    SCC --> SOAR["SecOps / SOAR"]
```

---

## Data Flow — Security & Audit

```mermaid
sequenceDiagram
    participant User
    participant WIF as Workforce Identity Federation
    participant IAM as Cloud IAM
    participant Proj as Workload Project
    participant Audit as Cloud Audit Logs
    participant Sink as Org Log Sink
    participant Archive as Log Archive (GCS)
    participant SCC as Security Command Center
    participant SIEM as Chronicle / SIEM

    User->>WIF: Authenticate (SAML/OIDC)
    WIF->>IAM: Federated token → Google credentials
    IAM->>Proj: Authorize action (conditional IAM)
    Proj->>Audit: Emit Admin/Data Access log
    Audit->>Sink: Route via org-level sink
    Sink->>Archive: Store (locked bucket, CMEK, retention)
    Audit->>SCC: Threat / anomaly detection
    SCC->>SIEM: Alert on finding
    SIEM->>User: Notify SOC (if policy violation)
```

---

## Workload Onboarding Flow

```mermaid
stateDiagram-v2
    [*] --> Request: Team submits project request
    Request --> Validate: Platform review
    Validate --> Reject: Policy violation
    Validate --> Provision: Approved
    Reject --> [*]

    Provision --> CreateProject: Project factory (Terraform)
    CreateProject --> AttachFolder: Assign folder (prod/nonprod)
    AttachFolder --> AttachSVPC: Attach to Shared VPC
    AttachSVPC --> ApplyIAM: Grant group-based IAM
    ApplyIAM --> ApplyLabels: Mandatory labels/tags
    ApplyLabels --> EnableAPIs: Enable approved APIs
    EnableAPIs --> ConfigPolicies: Org policies inherited
    ConfigPolicies --> EnableLogging: Log sink auto-included
    EnableLogging --> EnableSCC: SCC asset discovery
    EnableSCC --> Handoff: Ready for deployment
    Handoff --> [*]
```

---

## Multi-Region Design

```mermaid
flowchart TB
    subgraph GLOBAL["Global / Multi-Region"]
        DNS["Cloud DNS — global"]
        LB["Global External HTTP(S) LB"]
        ARMOR["Cloud Armor — global policy"]
        KMS["Cloud KMS — multi-region keys"]
    end

    subgraph US_C1["Region: us-central1"]
        NCC1["NCC Hub Attachment"]
        SVPC1["Shared VPC Subnets"]
        GKE1["GKE Regional Clusters"]
    end

    subgraph US_E1["Region: us-east1"]
        NCC2["NCC Hub Attachment"]
        SVPC2["Shared VPC Subnets"]
        GKE2["GKE Regional Clusters"]
    end

    subgraph EU_W1["Region: europe-west1"]
        NCC3["NCC Hub Attachment"]
        SVPC3["Shared VPC Subnets"]
        GKE3["GKE Regional Clusters"]
    end

    DNS --> LB
    LB --> ARMOR
    ARMOR --> US_C1 & US_E1 & EU_W1

    NCC1 --- NCC2 --- NCC3
    KMS --> US_C1 & US_E1 & EU_W1
```

---

## Mandatory Resource Labels (Tag Policy Equivalent)

| Label Key | Example | Enforced By |
|---|---|---|
| `environment` | prod, stg, dev, sandbox | Org policy / Config Controller |
| `cost-center` | CC-1234 | Org policy |
| `application` | payments-api | Org policy |
| `owner` | team-platform@corp.com | Org policy |
| `data-classification` | confidential, internal, public | Org policy |
| `compliance` | pci, hipaa, none | Org policy |
| `managed-by` | terraform | Config Controller |
