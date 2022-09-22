#
# Certificate postconditions example
#
# This is an example of using a `postcondition` to alert the expiration status of a
# self-signed certificate. If the certificate is ready for renewal the check will fail
# and alert the user.
#
# This code should be usable as-is.
#
# +---------------------------+--------+-----------------------------------------------+
# |         Resource          | Status |                    Message                    |
# +---------------------------+--------+-----------------------------------------------+
# | tls_self_signed_cert.user | Failed | Certificate will expire in less than 4 hours. |
# +---------------------------+--------+-----------------------------------------------+
#
# For a more concise example, the `tls_self_signed_cert` resource and postcondition
# check can be used on its own.
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "user" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "user" {
  private_key_pem = tls_private_key.user.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  early_renewal_hours   = 4
  validity_period_hours = 8
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
  ]
  is_ca_certificate = true

  lifecycle {
    postcondition {
      condition     = !self.ready_for_renewal
      error_message = "Certificate will expire in less than 4 hours."
    }
  }
}

resource "aws_iam_user" "user" {
  name = "eng-auto"
}

resource "aws_iam_signing_certificate" "user" {
  user_name        = aws_iam_user.user.name
  certificate_body = tls_self_signed_cert.user.cert_pem
}

output "user_arn" {
  value = aws_iam_user.user.arn

  # The user is not ready to use until the certificate is attached.
  depends_on = [
    aws_iam_signing_certificate.user,
  ]
}

#
# For a fuller results table, we can mock a few extra related results:
#
# +---------------------------+---------+-----------------------------------------------+
# |         Resource          | Status  |                    Message                    |
# +---------------------------+---------+-----------------------------------------------+
# | aws_instance.web          | Passed  | Postcondition passed.                         |
# | http.aws_check            | Passed  | Postcondition passed.                                      |
# | aws_db_instance.default   | Passed  | Postcondition passed.                                      |
# | null                      | Unknown | Unable to check because a series of failures prevented it. |
# | tls_self_signed_cert.user | Failed  | Certificate will expire in less than 4 hours.              |
# +---------------------------+---------+------------------------------------------------------------+

#
# Vault cert postconditions example
#
# This is an example of using a `postcondition` to alert the expiration status of a
# Vault-generated certificate. If the certificate is ready for renewal the check will fail
# and alert the user.
#
# This code can be used out-of-context to show postconditions working with other products.
# Unlike the above code, this will not run as-is.
#
# +-----------------------------------+--------+-------------------------------+
# |             Resource              | Status |           Message             |
# +-----------------------------------+--------+-------------------------------+
# | vault_pki_secret_backend_cert.app | Failed | Vault cert is ready to renew. |
# +-----------------------------------+--------+-------------------------------+
#
# #
# terraform {
#   required_providers {
#     vault = {
#       source = "hashicorp/vault"
#       version = "3.8.2"
#     }
#   }
# }

# provider "vault" {}

# resource "vault_pki_secret_backend_cert" "app" {
#   backend = vault_mount.intermediate.path
#   name = vault_pki_secret_backend_role.test.name
#   common_name = "app.my.domain"

#   lifecycle {
#     postcondition {
#       condition = !self.renew_pending
#       error_message = "Vault cert is ready to renew."
#     }
#   }
# }
