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
 * @notice Secp256k1 Unit Tests
 */
contract Secp256k1Test is Test {
    using Secp256k1 for SecretKey;
    using Secp256k1 for PublicKey;
    using Secp256k1 for Point;

    using Secp256k1Arithmetic for Point;
    using Secp256k1Arithmetic for ProjectivePoint;

    // Uncompressed Generator G.
    // Copied from [SEC-2 v2].
    bytes constant GENERATOR_ENCODED =
        hex"0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8";

    Secp256k1Wrapper wrapper;

    function setUp() public {
        wrapper = new Secp256k1Wrapper();
    }

    //--------------------------------------------------------------------------
    // Test: Constants

    function test_G() public {
        PublicKey memory got = wrapper.G();
        PublicKey memory want =
            Secp256k1.publicKeyFromEncoded(GENERATOR_ENCODED);

        assertEq(got.x, want.x);
        assertEq(got.y, want.y);
    }

    //--------------------------------------------------------------------------
    // Test: Secret Key

    // -- newSecretKey

    function test_newSecretKey() public {
        SecretKey sk = wrapper.newSecretKey();

        assertTrue(sk.isValid());

        // Verify vm can create wallet from secret key.
        vm.createWallet(sk.asUint());
    }

    // -- isValid

    function testFuzz_SecretKey_isValid(uint seed) public {
        uint scalar = _bound(seed, 1, Secp256k1.Q - 1);

        assertTrue(wrapper.isValid(SecretKey.wrap(scalar)));
    }

    function test_SecretKey_isValid_FailsIf_SecretKeyIsZero() public {
        assertFalse(wrapper.isValid(SecretKey.wrap(0)));
    }

    function testFuzz_SecretKey_isValid_FailsIf_SecretKeyGreaterOrEqualToQ(
        uint seed
    ) public {
        uint scalar = _bound(seed, Secp256k1.Q, type(uint).max);

        assertFalse(wrapper.isValid(SecretKey.wrap(scalar)));
    }

    // -- toPublicKey

    function testFuzz_SecretKey_toPublicKey(uint seed) public {
        SecretKey sk =
            Secp256k1.secretKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        address got = wrapper.toPublicKey(sk).toAddress();
        address want = vm.addr(sk.asUint());

        assertEq(got, want);
    }

    function testFuzz_SecretKey_toPublicKey_RevertsIf_SecretKeyInvalid(
        uint seed
    ) public {
        SecretKey sk = SecretKey.wrap(_bound(seed, Secp256k1.Q, type(uint).max));

        vm.expectRevert("SecretKeyInvalid()");
        wrapper.toPublicKey(sk);
    }

    // -- secretKeyFromUint

    function testFuzz_secretKeyFromUint(uint seed) public {
        uint scalar = _bound(seed, 1, Secp256k1.Q - 1);

        SecretKey sk = wrapper.secretKeyFromUint(scalar);

        assertTrue(sk.isValid());
        assertEq(sk.asUint(), scalar);
    }

    function test_secretKeyFromUint_RevertsIf_ScalarZero() public {
        vm.expectRevert("ScalarInvalid()");
        wrapper.secretKeyFromUint(0);
    }

    function test_secretKeyFromUint_RevertsIf_ScalarGreaterOrEqualToQ(uint seed)
        public
    {
        uint scalar = _bound(seed, Secp256k1.Q, type(uint).max);

        vm.expectRevert("ScalarInvalid()");
        wrapper.secretKeyFromUint(scalar);
    }

    // -- asUint

    function testFuzz_SecertKey_asUint(uint seed) public {
        assertEq(seed, wrapper.asUint(SecretKey.wrap(seed)));
    }

    //--------------------------------------------------------------------------
    // Test: Public Key

    // -- toAddress

    function testFuzz_PublicKey_toAddress(uint seed) public {
        SecretKey sk =
            Secp256k1.secretKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        address got = wrapper.toAddress(Secp256k1.toPublicKey(sk));
        address want = vm.addr(sk.asUint());

        assertEq(got, want);
    }

    // -- toHash

    function testFuzz_PublicKey_toHash(PublicKey memory pk) public {
        bytes32 got = wrapper.toHash(pk);
        bytes32 want = keccak256(abi.encodePacked(pk.x, pk.y));

        assertEq(got, want);
    }

    // -- isValid

    function testFuzz_PublicKey_isValid_If_CreatedViaValidSecretKey(uint seed)
        public
    {
        SecretKey sk =
            Secp256k1.secretKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        // Every public key created via valid secret key is valid.
        assertTrue(wrapper.isValid(sk.toPublicKey()));
    }

    function test_PublicKey_isValid_If_Identity() public {
        PublicKey memory pk = Secp256k1Arithmetic.Identity().intoPublicKey();

        assertTrue(pk.isValid());
    }

    function test_PublicKey_isValid_FailsIf_PointNotOnCurve() public {
        PublicKey memory pk;

        // Zero point not on curve.
        pk.x = 0;
        pk.y = 0;
        assertFalse(wrapper.isValid(pk));

        // Some other point.
        pk.x = 1;
        pk.x = 3;
        assertFalse(wrapper.isValid(pk));
    }

    // -- yParity

    function testFuzz_PublicKey_yParity(uint x, uint y) public {
        // yParity is 0 if y is even and 1 if y is odd.
        uint want = y % 2 == 0 ? 0 : 1;
        uint got = wrapper.yParity(PublicKey(x, y));

        assertEq(want, got);
    }

    // -- eq

    function testFuzz_PublicKey_eq(PublicKey memory pk1, PublicKey memory pk2)
        public
    {
        bool want = pk1.x == pk2.x && pk1.y == pk2.y;
        bool got = wrapper.eq(pk1, pk2);

        assertEq(want, got);
    }

    // -- intoPoint

    // TODO: Add no memory expansion tests for `into__()` functions.
    //       Must directly use library, not wrapper.

    function testFuzz_PublicKey_intoPoint(PublicKey memory pk) public {
        Point memory point = wrapper.intoPoint(pk);

        assertEq(point.x, pk.x);
        assertEq(point.y, pk.y);
    }

    // -- Point::intoPublicKey

    function testFuzz_Point_intoPublicKey(Point memory point) public {
        PublicKey memory pk = wrapper.intoPublicKey(point);

        assertEq(pk.x, point.x);
        assertEq(pk.y, point.y);
    }

    // -- toProjectivePoint

    function testFuzz_PublicKey_toProjectivePoint(PublicKey memory pk) public {
        ProjectivePoint memory point = wrapper.toProjectivePoint(pk);

        if (pk.intoPoint().isIdentity()) {
            assertTrue(point.isIdentity());
        } else {
            assertEq(point.x, pk.x);
            assertEq(point.y, pk.y);
            assertEq(point.z, 1);
        }
    }

    //--------------------------------------------------------------------------
    // Test: (De)Serialization

    //----------------------------------
    // Secret Key

    // -- SecretKey <-> Bytes

    function testFuzz_secretKeyFromBytes(uint scalar) public {
        bytes memory blob = abi.encodePacked(scalar);

        SecretKey sk = wrapper.secretKeyFromBytes(blob);

        assertEq(sk.asUint(), scalar);
    }

    function testFuzz_secretKeyFromBytes_RevertsIf_LengthNot32Bytes(
        bytes memory blob
    ) public {
        vm.assume(blob.length != 32);

        vm.expectRevert("LengthInvalid()");
        wrapper.secretKeyFromBytes(blob);
    }

    function testFuzz_SecretKey_toBytes(SecretKey sk) public {
        vm.assume(sk.isValid());

        bytes memory blob = wrapper.toBytes(sk);

        assertEq(sk.asUint(), Secp256k1.secretKeyFromBytes(blob).asUint());
    }

    //----------------------------------
    // Public Key

    // -- PublicKey <-> Bytes

    function testFuzz_publicKeyFromBytes(PublicKey memory pk1) public {
        bytes memory blob = pk1.toBytes();

        PublicKey memory pk2 = wrapper.publicKeyFromBytes(blob);

        assertTrue(pk1.eq(pk2));
    }

    function testFuzz_publicKeyFromBytes_RevertsIf_LengthNot64Bytes(
        bytes memory blob
    ) public {
        vm.assume(blob.length != 64);

        vm.expectRevert("LengthInvalid()");
        wrapper.publicKeyFromBytes(blob);
    }

    function testFuzz_PublicKey_toBytes(SecretKey sk) public {
        vm.assume(sk.isValid());

        PublicKey memory pk1 = sk.toPublicKey();

        bytes memory blob = wrapper.toBytes(pk1);
        assertEq(blob.length, 64);

        PublicKey memory pk2 = Secp256k1.publicKeyFromBytes(blob);
        assertTrue(pk1.eq(pk2));
    }

    // -- PublicKey <-> Encoded

    function test_publicKeyFromEncoded() public {
        bytes memory blob;
        PublicKey memory pk;

        // Generator.
        blob = GENERATOR_ENCODED;
        pk = wrapper.publicKeyFromEncoded(blob);
        assertTrue(pk.eq(Secp256k1.G()));

        // Some other point.
        blob =
            hex"0411111111111111111111111111111111111111111111111111111111111111112222222222222222222222222222222222222222222222222222222222222222";
        pk = wrapper.publicKeyFromEncoded(blob);
        assertTrue(
            pk.eq(
                PublicKey({
                    x: uint(
                        0x1111111111111111111111111111111111111111111111111111111111111111
                        ),
                    y: uint(
                        0x2222222222222222222222222222222222222222222222222222222222222222
                        )
                })
            )
        );
    }

    function test_publicKeyFromEncoded_Identity() public {
        bytes memory blob = hex"00";
        PublicKey memory pk;

        pk = wrapper.publicKeyFromEncoded(blob);
        assertTrue(pk.intoPoint().isIdentity());
    }

    function testFuzz_publicKeyFromEncoded_RevertsIf_LengthNot65BytesAndNotIdentity(
        bytes memory blob
    ) public {
        vm.assume(blob.length != 65);
        vm.assume(blob.length != 1 && bytes1(blob) != bytes1(0x00));

        vm.expectRevert("LengthInvalid()");
        wrapper.publicKeyFromEncoded(blob);
    }

    function testFuzz_publicKeyFromEncoded_RevertsIf_PrefixNot04AndNotIdentity(
        bytes1 prefix,
        PublicKey memory pk
    ) public {
        vm.assume(prefix != bytes1(0x04));

        bytes memory blob = abi.encodePacked(prefix, pk.x, pk.y);

        vm.expectRevert("PrefixInvalid()");
        wrapper.publicKeyFromEncoded(blob);
    }

    function test_PublicKey_toEncoded() public {
        PublicKey memory pk;
        bytes memory blob;

        // Generator.
        pk = Secp256k1.G();
        blob = wrapper.toEncoded(pk);
        assertEq(blob, GENERATOR_ENCODED);

        // Some other point.
        pk = PublicKey({
            x: uint(
                0x1111111111111111111111111111111111111111111111111111111111111111
                ),
            y: uint(
                0x2222222222222222222222222222222222222222222222222222222222222222
                )
        });
        blob = wrapper.toEncoded(pk);
        assertEq(
            blob,
            hex"0411111111111111111111111111111111111111111111111111111111111111112222222222222222222222222222222222222222222222222222222222222222"
        );
    }

    function test_PublicKey_toEncoded_Identity() public {
        PublicKey memory pk = Secp256k1Arithmetic.Identity().intoPublicKey();
        bytes memory blob = wrapper.toEncoded(pk);

        assertEq(blob, hex"00");
    }

    // -- PublicKey <-> CompressedEncoded

    function test_PublicKey_publicKeyFromCompressedEncoded() public {
        bytes memory blob;

        // TODO: Test publicKeyFromCompressedEncoded() once implemented.
        vm.expectRevert("NotImplemented()");
        wrapper.publicKeyFromCompressedEncoded(blob);
    }

    function test_PublicKey_toCompressedEncoded_IfyParityEven() public {
        PublicKey memory pk = PublicKey({
            x: uint(
                0x1111111111111111111111111111111111111111111111111111111111111111
                ),
            y: uint(2)
        });
        bytes memory blob = wrapper.toCompressedEncoded(pk);

        assertEq(
            blob,
            hex"021111111111111111111111111111111111111111111111111111111111111111"
        );
    }

    function test_PublicKey_toCompressedEncoded_IfyParityOdd() public {
        PublicKey memory pk = PublicKey({
            x: uint(
                0x1111111111111111111111111111111111111111111111111111111111111111
                ),
            y: uint(3)
        });
        bytes memory blob = wrapper.toCompressedEncoded(pk);

        assertEq(
            blob,
            hex"031111111111111111111111111111111111111111111111111111111111111111"
        );
    }

    function test_PublicKey_toCompressedEncoded_Identity() public {
        PublicKey memory pk = Secp256k1Arithmetic.Identity().intoPublicKey();
        bytes memory blob = wrapper.toCompressedEncoded(pk);

        assertEq(blob, hex"00");
    }
}

/**
 * @notice Library wrapper to enable forge coverage reporting
 *
 * @dev For more info, see https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086.
 */
contract Secp256k1Wrapper {
    using Secp256k1 for SecretKey;
    using Secp256k1 for PublicKey;
    using Secp256k1 for Point;

    using Secp256k1Arithmetic for Point;

    //--------------------------------------------------------------------------
    // Constants

    function G() public pure returns (PublicKey memory) {
        return Secp256k1.G();
    }

    //--------------------------------------------------------------------------
    // Secret Key

    function newSecretKey() public returns (SecretKey) {
        return Secp256k1.newSecretKey();
    }

    function isValid(SecretKey sk) public pure returns (bool) {
        return sk.isValid();
    }

    function toPublicKey(SecretKey sk) public returns (PublicKey memory) {
        return sk.toPublicKey();
    }

    function secretKeyFromUint(uint scalar) public pure returns (SecretKey) {
        return Secp256k1.secretKeyFromUint(scalar);
    }

    function asUint(SecretKey sk) public pure returns (uint) {
        return sk.asUint();
    }

    //--------------------------------------------------------------------------
    // Public Key

    function toAddress(PublicKey memory pk) public pure returns (address) {
        return pk.toAddress();
    }

    function toHash(PublicKey memory pk) public pure returns (bytes32) {
        return pk.toHash();
    }

    function isValid(PublicKey memory pk) public pure returns (bool) {
        return pk.isValid();
    }

    function yParity(PublicKey memory pk) public pure returns (uint) {
        return pk.yParity();
    }

    function eq(PublicKey memory pk, PublicKey memory other)
        public
        pure
        returns (bool)
    {
        return pk.eq(other);
    }

    function intoPoint(PublicKey memory pk)
        public
        pure
        returns (Point memory)
    {
        return pk.intoPoint();
    }

    function intoPublicKey(Point memory point)
        public
        pure
        returns (PublicKey memory)
    {
        return point.intoPublicKey();
    }

    function toProjectivePoint(PublicKey memory pk)
        public
        pure
        returns (ProjectivePoint memory)
    {
        return pk.toProjectivePoint();
    }

    //--------------------------------------------------------------------------
    // (De)Serialization

    //----------------------------------
    // Secret Key

    function secretKeyFromBytes(bytes memory blob)
        public
        pure
        returns (SecretKey)
    {
        return Secp256k1.secretKeyFromBytes(blob);
    }

    function toBytes(SecretKey sk) public pure returns (bytes memory) {
        return sk.toBytes();
    }

    //----------------------------------
    // Public Key

    function publicKeyFromBytes(bytes memory blob)
        public
        pure
        returns (PublicKey memory)
    {
        return Secp256k1.publicKeyFromBytes(blob);
    }

    function toBytes(PublicKey memory pk) public pure returns (bytes memory) {
        return pk.toBytes();
    }

    function publicKeyFromEncoded(bytes memory blob)
        public
        pure
        returns (PublicKey memory)
    {
        return Secp256k1.publicKeyFromEncoded(blob);
    }

    function toEncoded(PublicKey memory pk)
        public
        pure
        returns (bytes memory)
    {
        return pk.toEncoded();
    }

    function publicKeyFromCompressedEncoded(bytes memory blob)
        public
        pure
        returns (PublicKey memory)
    {
        return Secp256k1.publicKeyFromCompressedEncoded(blob);
    }

    function toCompressedEncoded(PublicKey memory pk)
        public
        pure
        returns (bytes memory)
    {
        return pk.toCompressedEncoded();
    }
}
