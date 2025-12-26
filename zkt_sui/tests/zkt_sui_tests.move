#[test_only]
module zkt_sui::zkt_sui_tests;
// uncomment this line to import the module
use zkt_sui::zkt_sui;

const ENotImplemented: u64 = 0;

#[test]
fun test_zkt_sui() {
    // pass
}

#[test, expected_failure(abort_code = ::zkt_sui::zkt_sui_tests::ENotImplemented)]
fun test_zkt_sui_fail() {
    abort ENotImplemented
}


