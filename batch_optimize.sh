#!/usr/bin/env bash

# Crurated Batch Optimization Script
# Provides easy access to gas analysis and batch optimization features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required environment variables are set
check_env_vars() {
    local required_vars=("PROXY_ADDRESS" "ADMIN" "OWNER")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        print_status "Please set them in your .env file or export them directly"
        print_status "Required variables:"
        print_status "  PROXY_ADDRESS - Address of deployed Crurated proxy contract"
        print_status "  ADMIN - Admin address for operations"
        print_status "  OWNER - Owner address"
        exit 1
    fi
}

# Function to load environment variables
load_env() {
    # Load from .env file if it exists
    if [ -f ".env" ]; then
        print_status "Loading environment variables from .env file"
        set -a  # automatically export all variables
        source .env
        set +a
    fi
    
    # Load from .env.local file if it exists (overrides .env)
    if [ -f ".env.local" ]; then
        print_status "Loading environment variables from .env.local file"
        set -a  # automatically export all variables
        source .env.local
        set +a
    fi
}

# Function to analyze mint gas usage
analyze_mint_gas() {
    print_status "Analyzing mint operation gas usage..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        --sig "analyzeMintGas()" \
        ${BROADCAST_FLAG}
    
    print_success "Mint gas analysis completed!"
}

# Function to analyze migrate gas usage
analyze_migrate_gas() {
    print_status "Analyzing migrate operation gas usage..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        --sig "analyzeMigrateGas()" \
        ${BROADCAST_FLAG}
    
    print_success "Migrate gas analysis completed!"
}

# Function to analyze incremental gas costs
analyze_incremental_costs() {
    print_status "Analyzing incremental gas costs..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        --sig "analyzeIncrementalGasCosts()" \
        ${BROADCAST_FLAG}
    
    print_success "Incremental gas cost analysis completed!"
}

# Function to execute sample mint operations
execute_sample_mints() {
    print_status "Executing sample mint operations with optimal batching..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        --sig "executeSampleMints()" \
        ${BROADCAST_FLAG}
    
    print_success "Sample mint execution completed!"
}

# Function to execute sample migrate operations
execute_sample_migrations() {
    print_status "Executing sample migrate operations with optimal batching..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        --sig "executeSampleMigrations()" \
        ${BROADCAST_FLAG}
    
    print_success "Sample migration execution completed!"
}

# Function to run full demonstration
run_full_demo() {
    print_status "Running full batch optimization demonstration..."
    
    forge script script/BatchOptimizationRunner.s.sol:BatchOptimizationRunner \
        --rpc-url ${RPC_URL:-http://localhost:8545} \
        ${BROADCAST_FLAG}
    
    print_success "Full demonstration completed!"
}

# Function to deploy contracts if needed
deploy_local() {
    print_status "Deploying contracts locally for testing..."
    
    # Check if anvil is running
    if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
        print_warning "Anvil not running. Starting anvil..."
        anvil &
        sleep 3
    fi

    # Deploy contracts
    ./deploy.sh local
    
    # Extract proxy address from deployment logs
    PROXY_ADDRESS=$(forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --sig "runLocal()" | grep -o "Proxy: 0x[a-fA-F0-9]\{40\}" | cut -d' ' -f2)
    
    if [ -n "$PROXY_ADDRESS" ]; then
        print_success "Contracts deployed. Proxy address: $PROXY_ADDRESS"
        echo "PROXY_ADDRESS=$PROXY_ADDRESS" >> .env.local
        echo "OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" >> .env.local
        echo "ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" >> .env.local
        print_status "Environment variables saved to .env.local"
    else
        print_error "Failed to extract proxy address from deployment"
        exit 1
    fi
}

# Function to show usage help
show_help() {
    echo "Crurated Batch Optimization Tool"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  analyze-mint           Analyze gas usage for mint operations"
    echo "  analyze-migrate        Analyze gas usage for migrate operations"
    echo "  analyze-costs          Analyze incremental gas costs"
    echo "  execute-mints          Execute sample mint operations with optimal batching"
    echo "  execute-migrations     Execute sample migrate operations with optimal batching"
    echo "  demo                   Run full demonstration of all features"
    echo "  deploy-local           Deploy contracts locally for testing"
    echo "  help                   Show this help message"
    echo ""
    echo "Options:"
    echo "  --broadcast            Broadcast transactions (for mainnet/testnet)"
    echo "  --rpc-url <url>        Custom RPC URL (default: http://localhost:8545)"
    echo ""
    echo "Environment Variables:"
    echo "  PROXY_ADDRESS          Address of deployed Crurated proxy contract"
    echo "  ADMIN                  Admin address for operations"
    echo "  OWNER                  Owner address"
    echo "  RPC_URL                RPC endpoint URL"
    echo ""
    echo "Examples:"
    echo "  $0 deploy-local                    # Deploy contracts locally and setup env"
    echo "  $0 analyze-mint                    # Analyze mint gas usage"
    echo "  $0 execute-mints --broadcast       # Execute sample mints on testnet"
    echo "  $0 demo                            # Run full demo locally"
    echo ""
    echo "For local testing:"
    echo "  1. Run '$0 deploy-local' first"
    echo "  2. Source the local environment: 'source .env.local'"
    echo "  3. Run any analysis or execution command"
}

# Parse command line arguments
BROADCAST_FLAG=""
RPC_URL="http://localhost:8545"

while [[ $# -gt 0 ]]; do
    case $1 in
        --broadcast)
            BROADCAST_FLAG="--broadcast"
            shift
            ;;
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Load environment variables
load_env

# Main script logic
case "${COMMAND:-help}" in
    "analyze-mint")
        check_env_vars
        analyze_mint_gas
        ;;
    "analyze-migrate")
        check_env_vars
        analyze_migrate_gas
        ;;
    "analyze-costs")
        check_env_vars
        analyze_incremental_costs
        ;;
    "execute-mints")
        check_env_vars
        execute_sample_mints
        ;;
    "execute-migrations")
        check_env_vars
        execute_sample_migrations
        ;;
    "demo")
        check_env_vars
        run_full_demo
        ;;
    "deploy-local")
        deploy_local
        ;;
    "help"|*)
        show_help
        ;;
esac