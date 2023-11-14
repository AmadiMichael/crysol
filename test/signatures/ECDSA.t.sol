// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {ECDSA, Signature} from "src/signatures/ECDSA.sol";
import {ECDSAUnsafe} from "unsafe/ECDSAUnsafe.sol";
import {Secp256k1, PrivateKey, PublicKey} from "src/curves/Secp256k1.sol";

/**
 * @notice ECDSA Unit Tests
 */
contract ECDSATest is Test {
    using ECDSA for address;
    using ECDSA for PrivateKey;
    using ECDSA for PublicKey;
    using ECDSA for Signature;
    using ECDSAUnsafe for Signature;

    using Secp256k1 for PrivateKey;
    using Secp256k1 for PublicKey;

    ECDSAWrapper wrapper;

    function setUp() public {
        wrapper = new ECDSAWrapper();
    }

    //--------------------------------------------------------------------------
    // Test: Signature Verification

    function testFuzz_verify(PrivateKey privKey, bytes memory message) public {
        vm.assume(privKey.isValid());

        PublicKey memory pubKey = privKey.toPublicKey();
        bytes32 digest = keccak256(message);

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(privKey.asUint(), digest);

        Signature memory sig = Signature(v, r, s);

        assertTrue(wrapper.verify(pubKey, message, sig));
        assertTrue(wrapper.verify(pubKey, digest, sig));
        assertTrue(wrapper.verify(pubKey.toAddress(), message, sig));
        assertTrue(wrapper.verify(pubKey.toAddress(), digest, sig));
    }

    function testFuzz_verify_FailsIf_SignatureInvalid(
        PrivateKey privKey,
        bytes memory message,
        uint8 vMask,
        uint rMask,
        uint sMask
    ) public {
        vm.assume(privKey.isValid());
        vm.assume(vMask != 0 || rMask != 0 || sMask != 0);

        PublicKey memory pubKey = privKey.toPublicKey();
        bytes32 digest = keccak256(message);

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(privKey.asUint(), digest);

        v ^= vMask;
        r = bytes32(uint(r) ^ rMask);
        s = bytes32(uint(s) ^ sMask);

        Signature memory sig = Signature(v, r, s);

        // Note that verify() reverts if signature is malleable.
        sig.intoNonMalleable();

        assertFalse(wrapper.verify(pubKey, message, sig));
        assertFalse(wrapper.verify(pubKey, digest, sig));
        assertFalse(wrapper.verify(pubKey.toAddress(), message, sig));
        assertFalse(wrapper.verify(pubKey.toAddress(), digest, sig));
    }

    function testFuzz_verify_RevertsIf_SignatureMalleable(
        PrivateKey privKey,
        bytes memory message
    ) public {
        vm.assume(privKey.isValid());

        PublicKey memory pubKey = privKey.toPublicKey();
        bytes32 digest = keccak256(message);

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(privKey.asUint(), digest);

        Signature memory badSig = Signature(v, r, s).intoMalleable();

        vm.expectRevert("SignatureMalleable()");
        wrapper.verify(pubKey, message, badSig);

        vm.expectRevert("SignatureMalleable()");
        wrapper.verify(pubKey, digest, badSig);

        vm.expectRevert("SignatureMalleable()");
        wrapper.verify(pubKey.toAddress(), message, badSig);

        vm.expectRevert("SignatureMalleable()");
        wrapper.verify(pubKey.toAddress(), digest, badSig);
    }

    function testFuzz_verify_RevertsIf_PublicKeyInvalid(
        PublicKey memory pubKey,
        bytes memory message,
        Signature memory sig
    ) public {
        vm.assume(!pubKey.isValid());

        vm.expectRevert("PublicKeyInvalid()");
        wrapper.verify(pubKey, message, sig);

        vm.expectRevert("PublicKeyInvalid()");
        wrapper.verify(pubKey, keccak256(message), sig);
    }

    function testFuzz_verify_RevertsIf_SignerZeroAddress(
        bytes memory message,
        Signature memory sig
    ) public {
        address signer = address(0);

        vm.expectRevert("SignerZeroAddress()");
        wrapper.verify(signer, message, sig);

        vm.expectRevert("SignerZeroAddress()");
        wrapper.verify(signer, keccak256(message), sig);
    }

    //--------------------------------------------------------------------------
    // Test: Signature Creation

    function testFuzz_sign(PrivateKey privKey, bytes memory message) public {
        vm.assume(privKey.isValid());

        PublicKey memory pubKey = privKey.toPublicKey();

        Signature memory sig1 = wrapper.sign(privKey, message);
        Signature memory sig2 = wrapper.sign(privKey, keccak256(message));

        assertEq(sig1.v, sig2.v);
        assertEq(sig1.r, sig2.r);
        assertEq(sig1.s, sig2.s);

        assertTrue(pubKey.verify(message, sig1));
        assertTrue(pubKey.verify(message, sig2));
    }

    function testFuzz_sign_RevertsIf_PrivateKeyInvalid(
        PrivateKey privKey,
        bytes memory message
    ) public {
        vm.assume(!privKey.isValid());

        vm.expectRevert("PrivateKeyInvalid()");
        wrapper.sign(privKey, message);

        vm.expectRevert("PrivateKeyInvalid()");
        wrapper.sign(privKey, keccak256(message));
    }

    // @todo Test property: Signature is non-malleable.

    // @todo Test signEthereum...

    //--------------------------------------------------------------------------
    // Test: Utils

    // -- Signature::isMalleable

    function testFuzz_Signature_isMalleable(Signature memory sig) public {
        vm.assume(uint(sig.s) > Secp256k1.Q / 2);

        assertTrue(wrapper.isMalleable(sig));
    }

    function testFuzz_Signature_isMalleable_FailsIf_SignatureNotMalleable(
        Signature memory sig
    ) public {
        vm.assume(uint(sig.s) <= Secp256k1.Q / 2);

        assertFalse(wrapper.isMalleable(sig));
    }

    // -- @todo Test: Signature::toString

    //--------------------------------------------------------------------------
    // Test: (De)Serialization
}

/**
 * @notice Library wrapper to enable forge coverage reporting
 *
 * @dev For more info, see https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086.
 */
contract ECDSAWrapper {
    using ECDSA for address;
    using ECDSA for PrivateKey;
    using ECDSA for PublicKey;
    using ECDSA for Signature;
    using ECDSAUnsafe for Signature;

    using Secp256k1 for PrivateKey;
    using Secp256k1 for PublicKey;

    //--------------------------------------------------------------------------
    // Signature Verification

    function verify(
        PublicKey memory pubKey,
        bytes memory message,
        Signature memory sig
    ) public pure returns (bool) {
        return pubKey.verify(message, sig);
    }

    function verify(
        PublicKey memory pubKey,
        bytes32 digest,
        Signature memory sig
    ) public pure returns (bool) {
        return pubKey.verify(digest, sig);
    }

    function verify(address signer, bytes memory message, Signature memory sig)
        public
        pure
        returns (bool)
    {
        return signer.verify(message, sig);
    }

    function verify(address signer, bytes32 digest, Signature memory sig)
        public
        pure
        returns (bool)
    {
        return signer.verify(digest, sig);
    }

    //--------------------------------------------------------------------------
    // Signature Creation

    function sign(PrivateKey privKey, bytes memory message)
        public
        view
        returns (Signature memory)
    {
        return privKey.sign(message);
    }

    function sign(PrivateKey privKey, bytes32 digest)
        public
        view
        returns (Signature memory)
    {
        return privKey.sign(digest);
    }

    function signEthereumSignedMessage(PrivateKey privKey, bytes memory message)
        public
        view
        returns (Signature memory)
    {
        return privKey.signEthereumSignedMessage(message);
    }

    function signEthereumSignedMessageHash(PrivateKey privKey, bytes32 digest)
        public
        view
        returns (Signature memory)
    {
        return privKey.signEthereumSignedMessageHash(digest);
    }

    //--------------------------------------------------------------------------
    // Utils

    function isMalleable(Signature memory sig) public pure returns (bool) {
        return sig.isMalleable();
    }

    function toString(Signature memory sig)
        public
        view
        returns (string memory)
    {
        return sig.toString();
    }

    //--------------------------------------------------------------------------
    // (De)Serialization

    function toBytes(Signature memory sig) public pure returns (bytes memory) {
        return sig.toBytes();
    }

    function signatureFromBytes(bytes memory blob)
        public
        pure
        returns (Signature memory)
    {
        return ECDSA.signatureFromBytes(blob);
    }

    function toCompactBytes(Signature memory sig)
        public
        pure
        returns (bytes memory)
    {
        return sig.toCompactBytes();
    }

    function signatureFromCompactBytes(bytes memory blob)
        public
        pure
        returns (Signature memory)
    {
        return ECDSA.signatureFromCompactBytes(blob);
    }
}
