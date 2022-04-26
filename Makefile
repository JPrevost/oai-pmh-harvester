.PHONY: install test lint dist update publish promote
SHELL=/bin/bash
ECR_REGISTRY=672626379771.dkr.ecr.us-east-1.amazonaws.com
DATETIME:=$(shell date -u +%Y%m%dT%H%M%SZ)


help: ## Print this message
	@awk 'BEGIN { FS = ":.*##"; print "Usage:  make <target>\n\nTargets:" } \
/^[-_[:alpha:]]+:.?*##/ { printf "  %-15s%s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install script and dependencies
	pipenv install --dev

test: ## Run tests and print a coverage report
	pipenv run coverage run --source=harvester -m pytest
	pipenv run coverage report -m

coveralls: test
	pipenv run coverage lcov -o ./coverage/lcov.info

### Linting commands ###
lint: bandit black flake8 isort mypy ## Lint the repo

bandit:
	pipenv run bandit -r harvester

black:
	pipenv run black --check --diff .

flake8:
	pipenv run flake8 .

isort:
	pipenv run isort . --diff

mypy:
	pipenv run mypy harvester


### Docker commands ###
dist: ## Build docker container
	docker build -t $(ECR_REGISTRY)/oaiharvester-stage:latest \
		-t $(ECR_REGISTRY)/oaiharvester-stage:`git describe --always` \
		-t oaiharvester .

update: install ## Update all Python dependencies
	pipenv clean
	pipenv update --dev

publish: ## Push and tag the latest image (use `make dist && make publish`)
	$$(aws ecr get-login --no-include-email --region us-east-1)
	docker push $(ECR_REGISTRY)/oaiharvester-stage:latest
	docker push $(ECR_REGISTRY)/oaiharvester-stage:`git describe --always`

promote: ## Promote the current staging build to production
	$$(aws ecr get-login --no-include-email --region us-east-1)
	docker pull $(ECR_REGISTRY)/oaiharvester-stage:latest
	docker tag $(ECR_REGISTRY)/oaiharvester-stage:latest $(ECR_REGISTRY)/oaiharvester-prod:latest
	docker tag $(ECR_REGISTRY)/oaiharvester-stage:latest $(ECR_REGISTRY)/oaiharvester-prod:$(DATETIME)
	docker push $(ECR_REGISTRY)/oaiharvester-prod:latest
	docker push $(ECR_REGISTRY)/oaiharvester-prod:$(DATETIME)
