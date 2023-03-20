SHELL := /bin/bash -exuo pipefail
PWD := $(shell pwd)

# target: req1 req2
# 	gcc -o $@ $^
# $@ = target
# $^ = req1 req2
# $* = % (wildcard match)

VERSION ?= latest
CONTAINER := alpine/terragrunt:$(VERSION)

DOCKER_ARGS := docker run \
		--interactive \
		--rm \
		--tty \
		--volume $(HOME)/.aws:/root/.aws \
		--volume $(HOME)/.ssh:/root/.ssh \
		--volume $(PWD):/apps

PLAN_FILE_NAME := planfile
PLAN_FILES := $(shell find . -name $(PLAN_FILE_NAME) | tr '\n' ' ' | awk 'BEGIN{FS=OFS=""}{NF--; print}')

.PHONY: list
list:
	LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

validate:
	$(DOCKER_ARGS) $(CONTAINER) terragrunt run-all validate | tee $@

plan: validate
	$(DOCKER_ARGS) $(CONTAINER) terragrunt run-all plan -out=$(PLAN_FILE_NAME) | tee $@

apply: plan
	$(DOCKER_ARGS) $(CONTAINER) terragrunt run-all apply $(PLAN_FILE_NAME) | tee $@

%.plan: validate
	$(DOCKER_ARGS) -w /apps/$* $(CONTAINER) terragrunt run-all plan -out=$(PLAN_FILE_NAME) | tee $@

%.apply: %.plan
	$(DOCKER_ARGS) -w /apps/$* $(CONTAINER) terragrunt run-all apply $(PLAN_FILE_NAME) | tee $@

.PHONY: show
show:
	$(foreach var,$(PLAN_FILES), $(DOCKER_ARGS) $(CONTAINER) bash -c "cd $(shell dirname $(var)) && terraform show";)

.PHONY: show.plan
show.plan:
	$(foreach var,$(PLAN_FILES), $(DOCKER_ARGS) $(CONTAINER) bash -c "cd $(shell dirname $(var)) && terraform show planfile";)

.PHONY: show.state
show.state:
	$(foreach var,$(PLAN_FILES), $(DOCKER_ARGS) $(CONTAINER) bash -c "cd $(shell dirname $(var)) && terraform state show";)

.PHONY: list.state
list.state:
	$(foreach var,$(PLAN_FILES), $(DOCKER_ARGS) $(CONTAINER) bash -c "cd $(shell dirname $(var)) && terraform state list";)

graph.svg:
	$(DOCKER_ARGS) $(CONTAINER) terragrunt graph-dependencies | dot -Tsvg > graph.svg

validate-ci:
	terragrunt run-all validate | tee $@

plan-ci: validate-ci
	terragrunt run-all plan -out=$(PLAN_FILE_NAME) | tee $@

apply-ci: plan-ci
	terragrunt run-all apply $(PLAN_FILE_NAME) | tee $@

%.plan-ci: validate-ci
	cd $*/; terragrunt run-all plan -out=$(PLAN_FILE_NAME) | tee $(PWD)/$@

%.apply-ci: %.plan-ci
	cd $*/; terragrunt run-all apply $(PLAN_FILE_NAME) | tee $(PWD)/$@

.PHONY: clean
clean:
	find . -name .terragrunt-cache | xargs rm -rf
	rm -f \
		*apply \
		*apply-ci \
		*plan \
		*plan-ci \
		validate \
		validate-ci