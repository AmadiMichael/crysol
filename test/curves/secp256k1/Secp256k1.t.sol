// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Secp256k1, PrivateKey, PublicKey} from "src/curves/Secp256k1.sol";

contract Secp256k1Test is Test {
    using Secp256k1 for PrivateKey;
    using Secp256k1 for PublicKey;

    // Uncompressed Generator G.
    // Copied from [Sec 2 v2].
    bytes constant GENERATOR_BYTES_UNCOMPRESSED =
        hex"0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8";

    //--------------------------------------------------------------------------
    // Test: Private Key

    // -- newPrivateKey

    function test_newPrivateKey() public {
        PrivateKey privKey = Secp256k1.newPrivateKey();

        assertTrue(privKey.isValid());

        // Verify vm can create wallet from private key.
        vm.createWallet(privKey.asUint());
    }

    // -- isValid

    function testFuzz_PrivateKey_isValid(uint seed) public {
        uint privKey = _bound(seed, 1, Secp256k1.Q - 1);

        assertTrue(PrivateKey.wrap(privKey).isValid());
    }

    function test_PrivateKey_isValid_FalseIf_PrivateKeyIsZero() public {
        assertFalse(PrivateKey.wrap(0).isValid());
    }

    function testFuzz_PrivateKey_isValid_FalseIf_PrivateKeyGreaterOrEqualToQ(
        uint seed
    ) public {
        uint privKey = _bound(seed, Secp256k1.Q, type(uint).max);

        assertFalse(PrivateKey.wrap(privKey).isValid());
    }

    // -- toPublicKey

    function testFuzz_PrivateKey_toPublicKey(uint seed) public {
        PrivateKey privKey =
            Secp256k1.privateKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        assertEq(privKey.toPublicKey().toAddress(), vm.addr(privKey.asUint()));
    }

    function testFuzz_PrivateKey_toPublicKey_RevertsIf_PrivateKeyInvalid(
        uint seed
    ) public {
        PrivateKey privKey =
            PrivateKey.wrap(_bound(seed, Secp256k1.Q, type(uint).max));

        vm.expectRevert("PrivateKeyInvalid()");
        privKey.toPublicKey();
    }

    //----------------------------------
    // Test: (De)Serialization

    // -- privateKeyFromUint

    function testFuzz_privateKeyFromUint(uint seed) public {
        uint scalar = _bound(seed, 1, Secp256k1.Q - 1);

        PrivateKey privKey = Secp256k1.privateKeyFromUint(scalar);

        assertEq(privKey.asUint(), scalar);
        assertTrue(privKey.isValid());
    }

    function testFuzz_privateKeyFromUint_RevertsIf_ScalarZero() public {
        vm.expectRevert("InvalidScalar()");
        Secp256k1.privateKeyFromUint(0);
    }

    function testFuzz_privateKeyFromUint_RevertsIf_ScalarGreaterOrEqualToQ(
        uint seed
    ) public {
        uint scalar = _bound(seed, Secp256k1.Q, type(uint).max);

        vm.expectRevert("InvalidScalar()");
        Secp256k1.privateKeyFromUint(scalar);
    }

    // -- asUint

    function testFuzz_PrivateKey_asUint(uint seed) public {
        assertEq(seed, PrivateKey.wrap(seed).asUint());
    }

    // -- privateKeyFromBytes

    function testFuzz_privateKeyFromBytes(uint seed) public {
        uint scalar = _bound(seed, 1, Secp256k1.Q - 1);

        PrivateKey privKey =
            Secp256k1.privateKeyFromBytes(abi.encodePacked(scalar));

        assertTrue(privKey.isValid());
        assertEq(privKey.asUint(), scalar);
    }

    function testFuzz_privateKeyFromBytes_RevertsIf_LengthNot32Bytes(
        bytes memory seed
    ) public {
        vm.assume(seed.length != 32);

        vm.expectRevert("InvalidLength()");
        Secp256k1.privateKeyFromBytes(seed);
    }

    function testFuzz_privateKeyFromBytes_RevertsIf_DeserializedScalarInvalid(
        uint seed
    ) public {
        uint scalar =
            seed == 0 ? seed : _bound(seed, Secp256k1.Q, type(uint).max);

        vm.expectRevert("InvalidScalar()");
        Secp256k1.privateKeyFromBytes(abi.encodePacked(scalar));
    }

    // -- asBytes

    function testFuzz_PrivateKey_asBytes(PrivateKey privKey) public {
        vm.assume(privKey.isValid());

        assertEq(
            privKey.asUint(),
            Secp256k1.privateKeyFromBytes(privKey.asBytes()).asUint()
        );
    }

    //--------------------------------------------------------------------------
    // Test: Public Key

    // -- toAddress

    function testFuzz_PublicKey_toAddress(uint seed) public {
        PrivateKey privKey =
            Secp256k1.privateKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        assertEq(privKey.toPublicKey().toAddress(), vm.addr(privKey.asUint()));
    }

    // -- toHash

    function testFuzz_PublicKey_toHash(PublicKey memory pubKey) public {
        bytes32 got = pubKey.toHash();
        bytes32 want = keccak256(abi.encodePacked(pubKey.x, pubKey.y));

        assertEq(got, want);
    }

    // -- isValid

    function testFuzz_PublicKey_isValid(uint seed) public {
        PrivateKey privKey =
            Secp256k1.privateKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        // Every public key created via valid private key is valid.
        assertTrue(privKey.toPublicKey().isValid());
    }

    function test_PublicKey_isValid_FalseIf_PointNotOnCurve() public {
        PublicKey memory pubKey;

        pubKey.x = 0;
        pubKey.y = 0;
        assertFalse(pubKey.isValid());

        pubKey.x = 1;
        pubKey.x = 3;
        assertFalse(pubKey.isValid());

        pubKey.x = type(uint).max;
        pubKey.x = type(uint).max;
        assertFalse(pubKey.isValid());
    }

    // -- yParity

    function testFuzz_PublicKey_yParity(uint x, uint y) public {
        // yParity is 0 if y is even and 1 if y is odd.
        uint want = y % 2 == 0 ? 0 : 1;
        uint got = PublicKey(x, y).yParity();

        assertEq(want, got);
    }

    // @todo Test: Arithmetic conversions

    //----------------------------------
    // Test: (De)Serialization

    // -- publicKeyFromBytes

    function testFuzz_publicKeyFromBytes(uint seed) public {
        PrivateKey privKey =
            Secp256k1.privateKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        PublicKey memory pubKey = privKey.toPublicKey();

        address want = pubKey.toAddress();
        address got = Secp256k1.publicKeyFromBytes(pubKey.asBytes()).toAddress();

        assertEq(want, got);
    }

    function test_publicKeyFromBytes_ViaGenerator() public {
        PublicKey memory want = Secp256k1.G();
        PublicKey memory got =
            Secp256k1.publicKeyFromBytes(GENERATOR_BYTES_UNCOMPRESSED);

        assertEq(want.toAddress(), got.toAddress());
    }

    function testFuzz_publicKeyFromBytes_RevertsIf_LengthNot65Bytes(
        bytes memory blob
    ) public {
        vm.assume(blob.length != 65);

        vm.expectRevert("InvalidLength()");
        Secp256k1.publicKeyFromBytes(blob);
    }

    function testFuzz_publicKeyFromBytes_RevertsIf_PrefixByteNot0x04(
        bytes1 prefix
    ) public {
        vm.assume(prefix != bytes1(0x04));

        bytes memory blob = abi.encodePacked(prefix, bytes32(""), bytes32(""));

        vm.expectRevert("InvalidPrefix()");
        Secp256k1.publicKeyFromBytes(blob);
    }

    function testFuzz_publicKeyFromBytes_RevertsIf_DeserializedPublicKeyInvalid(
        PublicKey memory pubKey
    ) public {
        vm.assume(!pubKey.isValid());

        vm.expectRevert("InvalidPublicKey()");
        Secp256k1.publicKeyFromBytes(pubKey.asBytes());
    }

    // -- asBytes

    function testFuzz_PublicKey_asBytes(uint seed) public {
        PrivateKey privKey =
            Secp256k1.privateKeyFromUint(_bound(seed, 1, Secp256k1.Q - 1));

        PublicKey memory pubKey = privKey.toPublicKey();

        address want = pubKey.toAddress();
        address got = Secp256k1.publicKeyFromBytes(pubKey.asBytes()).toAddress();

        assertEq(want, got);
    }

    function test_PublicKey_asBytes_ViaGenerator() public {
        assertEq(GENERATOR_BYTES_UNCOMPRESSED, Secp256k1.G().asBytes());
    }

    // @todo Test: Compressed bytes serde
}
