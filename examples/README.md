# Examples

- Create a directory for each example.
- Create a `_header.md` file in each directory to describe the example.
- See the `default` example provided as a skeleton - this must remain, but you can add others.
- Run `make fmt && make docs` from the repo root to generate the required documentation.

> **Note:** Examples must be deployable and idempotent. Ensure that no input variables are required to run the example and that random values are used to ensure unique resource names. E.g. use the [naming module](https://registry.terraform.io/modules/Azure/naming/azurerm/latest) to generate a unique name for a resource.

## E2E Testing Infrastructure

Each example now includes comprehensive end-to-end testing:

### Test Components
- **test.tftest.hcl**: Native Terraform tests with plan and apply assertions
- **outputs.tf**: Output definitions for validation and debugging
- **Automated CI/CD**: Integration with AVM framework for automated testing

### Available Examples with Tests

1. **default**: Basic Databricks workspace (standard SKU)
2. **private-endpoint**: VNet injection with private endpoints (premium SKU)
3. **customer-managed-key**: Customer managed encryption keys (premium SKU)
4. **diagnostic-settings**: Monitoring and logging integration (premium SKU)

### Running Tests Locally

```bash
# Test a specific example
cd examples/default
terraform init
terraform test -verbose

# Test all examples
find examples -name "test.tftest.hcl" -exec dirname {} \; | while read dir; do
  echo "Testing $dir"
  cd "$dir" && terraform init && terraform test
  cd - > /dev/null
done
```

### Test Coverage
Each test validates:
- Resource configuration matches expectations
- Terraform plans execute successfully  
- Resources deploy correctly
- Outputs are populated with expected values
- Example-specific features work as intended
