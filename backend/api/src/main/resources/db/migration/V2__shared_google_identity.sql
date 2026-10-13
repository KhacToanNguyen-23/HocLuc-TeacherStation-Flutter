-- Shared application identity; exam ownership keeps the existing account IDs.
CREATE TABLE external_identities (
 provider VARCHAR(24) NOT NULL,
 subject VARCHAR(255) NOT NULL,
 account_id VARCHAR(36) NOT NULL REFERENCES accounts(id),
 PRIMARY KEY(provider,subject),
 UNIQUE(provider,account_id)
);
