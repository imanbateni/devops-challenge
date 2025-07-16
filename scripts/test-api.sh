#!/bin/bash
set -e

API_URL="http://localhost/api"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🧪 Running API Tests..."
echo "========================"

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        exit 1
    fi
}

# Test 1: Health Check
echo -n "Testing health endpoint... "
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" ${API_URL}/health)
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HEALTH_CODE" = "200" ] && echo "$HEALTH_BODY" | grep -q "healthy"; then
    print_result 0 "Health check passed"
else
    print_result 1 "Health check failed (HTTP $HEALTH_CODE)"
fi

# Test 2: Create User
echo -n "Testing user creation... "
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/users \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser'$(date +%s)'","email":"test'$(date +%s)'@example.com"}')
CREATE_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
CREATE_BODY=$(echo "$CREATE_RESPONSE" | head -n-1)

if [ "$CREATE_CODE" = "201" ] && echo "$CREATE_BODY" | grep -q "success.*true"; then
    print_result 0 "User creation passed"
else
    print_result 1 "User creation failed (HTTP $CREATE_CODE)"
fi

# Test 3: List Users
echo -n "Testing user listing... "
LIST_RESPONSE=$(curl -s -w "\n%{http_code}" ${API_URL}/users)
LIST_CODE=$(echo "$LIST_RESPONSE" | tail -n1)
LIST_BODY=$(echo "$LIST_RESPONSE" | head -n-1)

if [ "$LIST_CODE" = "200" ] && echo "$LIST_BODY" | grep -q "success.*true"; then
    print_result 0 "User listing passed"
else
    print_result 1 "User listing failed (HTTP $LIST_CODE)"
fi

# Test 4: Input Validation
echo -n "Testing input validation... "
VALIDATION_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/users \
    -H "Content-Type: application/json" \
    -d '{"username":"ab","email":"invalid-email"}')
VALIDATION_CODE=$(echo "$VALIDATION_RESPONSE" | tail -n1)

if [ "$VALIDATION_CODE" = "400" ]; then
    print_result 0 "Input validation passed"
else
    print_result 1 "Input validation failed (expected 400, got $VALIDATION_CODE)"
fi

# Test 5: Duplicate User
echo -n "Testing duplicate user handling... "
UNIQUE_USER="duptest$(date +%s)"
curl -s -X POST ${API_URL}/users \
    -H "Content-Type: application/json" \
    -d '{"username":"'$UNIQUE_USER'","email":"'$UNIQUE_USER'@example.com"}' > /dev/null

DUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/users \
    -H "Content-Type: application/json" \
    -d '{"username":"'$UNIQUE_USER'","email":"'$UNIQUE_USER'@example.com"}')
DUP_CODE=$(echo "$DUP_RESPONSE" | tail -n1)

if [ "$DUP_CODE" = "409" ]; then
    print_result 0 "Duplicate user handling passed"
else
    print_result 1 "Duplicate user handling failed (expected 409, got $DUP_CODE)"
fi

## Test 6: Load Balancing
#echo -n "Testing load balancing... "
#CONTAINER1_COUNT=0
#CONTAINER2_COUNT=0
#
#for i in {1..10}; do
#    RESPONSE=$(curl -s ${API_URL}/health)
#    # In a real scenario, we'd check response headers or logs
#    # For now, we just verify the endpoint responds
#    if [ $? -eq 0 ]; then
#        ((CONTAINER1_COUNT++))
#    fi
#done
#
#if [ $CONTAINER1_COUNT -gt 0 ]; then
#    print_result 0 "Load balancing verified (requests distributed)"
#else
#    print_result 1 "Load balancing failed"
#fi
#
#echo "========================"
#echo -e "${GREEN}All tests passed! 🎉${NC}"