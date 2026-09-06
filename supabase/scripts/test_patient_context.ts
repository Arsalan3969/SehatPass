// ==============================================================================
// SehatPass: Patient Context Unit & Logic Verification Suite
// ==============================================================================
import { calculateAge } from "../functions/sehat-ai/index";

function assert(condition: boolean, msg: string) {
  if (!condition) {
    throw new Error(`Assertion Failed: ${msg}`);
  }
}

console.log("==================================================================");
console.log("  Sehat AI Patient Context: Logic & Age Calculation Tests");
console.log("==================================================================");

// Test 1: Age calculation with valid dates
const age1 = calculateAge("2000-01-01");
console.log(`[Test 1] calculateAge('2000-01-01') = ${age1}`);
assert(typeof age1 === "number" && age1 >= 25, "Age for year 2000 should be >= 25");

// Test 2: Missing or invalid dates return undefined
assert(calculateAge(undefined) === undefined, "Undefined DOB should return undefined");
assert(calculateAge(null) === undefined, "Null DOB should return undefined");
assert(calculateAge("") === undefined, "Empty DOB should return undefined");
assert(calculateAge("invalid-date") === undefined, "Invalid DOB should return undefined");
console.log("[Test 2] Missing / invalid DOB returned undefined (PASS)");

// Test 3: Future dates return undefined
assert(calculateAge("2099-01-01") === undefined, "Future DOB should return undefined");
console.log("[Test 3] Future DOB returned undefined (PASS)");

console.log("==================================================================");
console.log("  All Sehat AI Patient Context Logic Tests PASSED!");
console.log("==================================================================");
