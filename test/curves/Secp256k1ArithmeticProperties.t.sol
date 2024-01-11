// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Secp256k1, SecretKey, PublicKey} from "src/curves/Secp256k1.sol";
import {
    Secp256k1Arithmetic,
    Point,
    ProjectivePoint
} from "src/curves/Secp256k1Arithmetic.sol";

/**
 * @notice Secp256k1Arithmetic Property Tests
 */
contract Secp256k1ArithmeticPropertiesTest is Test {
    using Secp256k1 for SecretKey;
    using Secp256k1 for PublicKey;
    using Secp256k1 for Point;

    using Secp256k1Arithmetic for Point;
    using Secp256k1Arithmetic for ProjectivePoint;

    //--------------------------------------------------------------------------
    // Test: Projective Point

    function testProperty_ProjectivePoint_add_NeverReturnsZeroPoint(
        SecretKey sk1,
        SecretKey sk2
    ) public {
        vm.assume(sk1.isValid());
        vm.assume(sk2.isValid());

        ProjectivePoint memory p1 = sk1.toPublicKey().toProjectivePoint();
        ProjectivePoint memory p2 = sk2.toPublicKey().toProjectivePoint();

        Point memory sum = p1.add(p2).intoPoint();

        assertFalse(sum.isZeroPoint());
    }

    function testProperty_ProjectivePoint_add_ResultIsOnCurve(
        SecretKey sk1,
        SecretKey sk2
    ) public {
        vm.assume(sk1.isValid());
        vm.assume(sk2.isValid());

        ProjectivePoint memory p1 = sk1.toPublicKey().toProjectivePoint();
        ProjectivePoint memory p2 = sk2.toPublicKey().toProjectivePoint();

        Point memory sum = p1.add(p2).intoPoint();

        assertTrue(sum.isOnCurve());
    }

    //--------------------------------------------------------------------------
    // Test: (De)Serialization

    //----------------------------------
    // Secret Key

    function testProperty_SecretKey_Bytes_SerializationLoop(SecretKey start)
        public
    {
        SecretKey end = Secp256k1.secretKeyFromBytes(start.toBytes());

        assertEq(start.asUint(), end.asUint());
    }

    //----------------------------------
    // Public Key

    function testProperty_PublicKey_Bytes_SerializationLoop(
        PublicKey memory start
    ) public {
        PublicKey memory end = Secp256k1.publicKeyFromBytes(start.toBytes());

        assertTrue(start.eq(end));
    }

    function testProperty_PublicKey_Encoded_SerializationLoop(
        PublicKey memory start
    ) public {
        PublicKey memory end = Secp256k1.publicKeyFromEncoded(start.toEncoded());

        assertTrue(start.eq(end));
    }
}
