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
 * @notice Secp256k1Arithmetic Unit Tests
 */
contract Secp256k1ArithmeticTest is Test {
    using Secp256k1Arithmetic for Point;
    using Secp256k1Arithmetic for ProjectivePoint;

    using Secp256k1 for SecretKey;
    using Secp256k1 for PublicKey;

    Secp256k1ArithmeticWrapper wrapper;

    function setUp() public {
        wrapper = new Secp256k1ArithmeticWrapper();
    }

    //--------------------------------------------------------------------------
    // Test: Point

    // -- zeroPoint

    function test_zeroPoint() public {
        assertTrue(wrapper.zeroPoint().isZeroPoint());
    }

    // -- isZeroPoint

    function testFuzz_Point_isZeroPoint(Point memory point) public {
        if (point.x == 0 && point.y == 0) {
            assertTrue(wrapper.isZeroPoint(point));
        } else {
            assertFalse(wrapper.isZeroPoint(point));
        }
    }

    // -- identity

    function test_identity() public {
        assertTrue(wrapper.identity().isIdentity());
    }

    // -- isIdentity

    function testFuzz_Point_isIdentity(Point memory point) public {
        if (point.x == type(uint).max && point.y == type(uint).max) {
            assertTrue(wrapper.isIdentity(point));
        } else {
            assertFalse(wrapper.isIdentity(point));
        }
    }

    // -- isOnCurve

    function testFuzz_Point_isOnCurve(SecretKey sk) public {
        vm.assume(sk.isValid());

        Point memory point = sk.toPublicKey().intoPoint();

        assertTrue(wrapper.isOnCurve(point));
    }

    function test_Point_isOnCurve_Identity() public {
        assertTrue(wrapper.isOnCurve(Secp256k1Arithmetic.identity()));
    }

    function testFuzz_Point_isOnCurve_FailsIf_NotOnCurve(
        SecretKey sk,
        uint xMask,
        uint yMask
    ) public {
        vm.assume(sk.isValid());
        vm.assume(xMask != 0 || yMask != 0);

        Point memory point = sk.toPublicKey().intoPoint();

        // Mutate point.
        point.x ^= xMask;
        point.y ^= yMask;

        assertFalse(wrapper.isOnCurve(point));
    }

    // -- yParity

    function testFuzz_Point_yParity(uint x, uint y) public {
        // yParity is 0 if y is even and 1 if y is odd.
        uint want = y % 2 == 0 ? 0 : 1;
        uint got = wrapper.yParity(Point(x, y));

        assertEq(want, got);
    }

    //--------------------------------------------------------------------------
    // Test: Projective Point

    // -- projectiveIdentity

    function test_projectiveIdentity() public {
        assertTrue(wrapper.projectiveIdentity().isIdentity());
    }

    // -- isIdentity

    function testFuzz_ProjectivePoint_isIdentity(ProjectivePoint memory jPoint)
        public
    {
        if (jPoint.x == 0 && jPoint.y == 1 && jPoint.z == 0) {
            assertTrue(wrapper.isIdentity(jPoint));
        } else {
            assertFalse(wrapper.isIdentity(jPoint));
        }
    }

    // -- add

    function test_ProjectivePoint_add() public {
        // TODO: Use vectors from RustCrypto and/or Paul Miller's noble-curves.

        ProjectivePoint memory a;
        ProjectivePoint memory b;
        Point memory sum;

        // sum = [1]G + [2]G = [3]G
        a = Secp256k1Arithmetic.G().toProjectivePoint();
        b = Secp256k1.secretKeyFromUint(2).toPublicKey().toProjectivePoint();
        sum = wrapper.add(a, b).intoPoint();

        Point memory want =
            Secp256k1.secretKeyFromUint(3).toPublicKey().intoPoint();

        assertEq(sum.x, want.x);
        assertEq(sum.y, want.y);
    }

    function testFuzz_ProjectivePoint_add_RevertsIf_Double(
        ProjectivePoint memory jPoint
    ) public {
        vm.expectRevert();
        wrapper.add(jPoint, jPoint);
    }

    // -- double

    function test_ProjectivePoint_double() public {
        ProjectivePoint memory p = Secp256k1Arithmetic.G().toProjectivePoint();

        Point memory want =
            Secp256k1.secretKeyFromUint(4).toPublicKey().intoPoint();
        Point memory got = p.double().double().intoPoint();

        assertEq(got.x, want.x);
        assertEq(got.y, want.y);
    }

    // -- mul

    function test_ProjectivePoint_mul() public {
        ProjectivePoint memory p = Secp256k1Arithmetic.G().toProjectivePoint();
        uint scalar = 10;

        Point memory want =
            Secp256k1.secretKeyFromUint(scalar).toPublicKey().intoPoint();
        Point memory got = p.mul(scalar).intoPoint();

        assertEq(got.x, want.x);
        assertEq(got.y, want.y);
    }

    //--------------------------------------------------------------------------
    // (De)Serialization

    //----------------------------------
    // Point

    // -- toProjectivePoint

    function testFuzz_Point_toProjectivePoint(SecretKey sk) public {
        vm.assume(sk.isValid());

        Point memory want = sk.toPublicKey().intoPoint();
        Point memory got = wrapper.toProjectivePoint(want).intoPoint();

        assertEq(want.x, got.x);
        assertEq(want.y, got.y);
    }

    function test_Point_toProjectivePoint_Identity() public {
        Point memory identity = Secp256k1Arithmetic.identity();

        assertTrue(wrapper.toProjectivePoint(identity).isIdentity());
    }

    //----------------------------------
    // Projective Point

    // TODO: Test no new memory allocation.
    // TODO: Not a real test. Use vectors from Paul Miller.
    function testFuzz_ProjectivePoint_intoPoint(SecretKey sk) public {
        vm.assume(sk.isValid());

        Point memory want = sk.toPublicKey().intoPoint();
        Point memory got = wrapper.intoPoint(want.toProjectivePoint());

        assertEq(want.x, got.x);
        assertEq(want.y, got.y);
    }

    function test_ProjectivePoint_intoPoint_Identity() public {
        ProjectivePoint memory identity =
            Secp256k1Arithmetic.projectiveIdentity();

        assertTrue(wrapper.intoPoint(identity).isIdentity());
    }

    //--------------------------------------------------------------------------
    // Test: Utils

    // -- modularInverseOf

    function testFuzz_modularInverseOf(uint x) public {
        vm.assume(x != 0);
        vm.assume(x < Secp256k1Arithmetic.P);

        uint xInv = Secp256k1Arithmetic.modularInverseOf(x);

        // Verify x * xInv ≡ 1 (mod P).
        assertEq(mulmod(x, xInv, Secp256k1Arithmetic.P), 1);
    }

    function test_modularInverseOf_RevertsIf_XIsZero() public {
        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.modularInverseOf(0);
    }

    function testFuzz_modularInverseOf_RevertsIf_XEqualToOrBiggerThanP(uint x)
        public
    {
        vm.assume(x >= Secp256k1Arithmetic.P);

        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.modularInverseOf(x);
    }

    // -- areModularInverse

    function testFuzz_areModularInverse(uint x) public {
        vm.assume(x != 0);
        vm.assume(x < Secp256k1Arithmetic.P);

        assertTrue(
            wrapper.areModularInverse(
                x, Secp256k1Arithmetic.modularInverseOf(x)
            )
        );
    }

    function testFuzz_areModularInverse_FailsIf_NotModularInverse(
        uint x,
        uint xInv
    ) public {
        vm.assume(x != 0);
        vm.assume(x < Secp256k1Arithmetic.P);
        vm.assume(xInv != 0);
        vm.assume(xInv < Secp256k1Arithmetic.P);

        vm.assume(mulmod(x, xInv, Secp256k1Arithmetic.P) != 1);

        assertFalse(wrapper.areModularInverse(x, xInv));
    }

    function test_areModularInverse_RevertsIf_XIsZero() public {
        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.areModularInverse(0, 1);
    }

    function test_areModularInverse_RevertsIf_XInvIsZero() public {
        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.areModularInverse(1, 0);
    }

    function testFuzz_areModularInverse_RevertsIf_XEqualToOrBiggerThanP(uint x)
        public
    {
        vm.assume(x >= Secp256k1Arithmetic.P);

        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.areModularInverse(x, 1);
    }

    function testFuzz_areModularInverse_RevertsIf_XInvEqualToOrBiggerThanP(
        uint xInv
    ) public {
        vm.assume(xInv >= Secp256k1Arithmetic.P);

        // TODO: Test for proper error message.
        vm.expectRevert();
        wrapper.areModularInverse(1, xInv);
    }
}

/**
 * @notice Library wrapper to enable forge coverage reporting
 *
 * @dev For more info, see https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086.
 */
contract Secp256k1ArithmeticWrapper {
    using Secp256k1Arithmetic for Point;
    using Secp256k1Arithmetic for ProjectivePoint;

    //--------------------------------------------------------------------------
    // Constants

    function G() public pure returns (Point memory) {
        return Secp256k1Arithmetic.G();
    }

    //--------------------------------------------------------------------------
    // Point

    function zeroPoint() public pure returns (Point memory) {
        return Secp256k1Arithmetic.zeroPoint();
    }

    function isZeroPoint(Point memory point) public pure returns (bool) {
        return point.isZeroPoint();
    }

    function identity() public pure returns (Point memory) {
        return Secp256k1Arithmetic.identity();
    }

    function isIdentity(Point memory point) public pure returns (bool) {
        return point.isIdentity();
    }

    function isOnCurve(Point memory point) public pure returns (bool) {
        return point.isOnCurve();
    }

    function yParity(Point memory point) public pure returns (uint) {
        return point.yParity();
    }

    //--------------------------------------------------------------------------
    // Projective Point

    function projectiveIdentity()
        public
        pure
        returns (ProjectivePoint memory)
    {
        return Secp256k1Arithmetic.projectiveIdentity();
    }

    function isIdentity(ProjectivePoint memory jPoint)
        public
        pure
        returns (bool)
    {
        return jPoint.isIdentity();
    }

    //--------------------------------------------------------------------------
    // (De)Serialization

    //----------------------------------
    // Point

    function toProjectivePoint(Point memory point)
        public
        pure
        returns (ProjectivePoint memory)
    {
        return point.toProjectivePoint();
    }

    //----------------------------------
    // Projective Point

    function intoPoint(ProjectivePoint memory jPoint)
        public
        pure
        returns (Point memory)
    {
        return jPoint.intoPoint();
    }

    function add(ProjectivePoint memory jPoint, ProjectivePoint memory jOther)
        public
        pure
        returns (ProjectivePoint memory)
    {
        return jPoint.add(jOther);
    }

    //--------------------------------------------------------------------------
    // Utils

    function modularInverseOf(uint x) public pure returns (uint) {
        return Secp256k1Arithmetic.modularInverseOf(x);
    }

    function areModularInverse(uint x, uint xInv) public pure returns (bool) {
        return Secp256k1Arithmetic.areModularInverse(x, xInv);
    }
}
