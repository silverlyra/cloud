AWS_PROFILE ?= lyra
VAULT := aws-vault exec --no-session $(AWS_PROFILE) --

.PHONY: all plan apply destroy output configure-state

all: plan

plan:
	$(VAULT) terraform plan

apply:
	$(VAULT) terraform apply

destroy:
	$(VAULT) terraform destroy

output:
	$(VAULT) terraform output
