package auth

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"math/big"
)

func verifyJWKSignature(key jwk, alg string, input []byte, signature []byte) error {
	digest := sha256.Sum256(input)
	switch alg {
	case "RS256":
		publicKey, err := rsaPublicKey(key)
		if err != nil {
			return err
		}
		return rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, digest[:], signature)
	case "ES256":
		publicKey, err := ecdsaPublicKey(key)
		if err != nil {
			return err
		}
		if len(signature) != 64 {
			return errors.New("invalid_ecdsa_signature")
		}
		r := new(big.Int).SetBytes(signature[:32])
		s := new(big.Int).SetBytes(signature[32:])
		if ecdsa.Verify(publicKey, digest[:], r, s) {
			return nil
		}
		return errors.New("invalid_ecdsa_signature")
	default:
		return errors.New("unsupported_identity_alg")
	}
}

func rsaPublicKey(key jwk) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(key.N)
	if err != nil {
		return nil, err
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(key.E)
	if err != nil {
		return nil, err
	}
	e := 0
	for _, b := range eBytes {
		e = e*256 + int(b)
	}
	return &rsa.PublicKey{N: new(big.Int).SetBytes(nBytes), E: e}, nil
}

func ecdsaPublicKey(key jwk) (*ecdsa.PublicKey, error) {
	if key.Crv != "P-256" {
		return nil, errors.New("unsupported_ec_curve")
	}
	xBytes, err := base64.RawURLEncoding.DecodeString(key.X)
	if err != nil {
		return nil, err
	}
	yBytes, err := base64.RawURLEncoding.DecodeString(key.Y)
	if err != nil {
		return nil, err
	}
	return &ecdsa.PublicKey{
		Curve: elliptic.P256(),
		X:     new(big.Int).SetBytes(xBytes),
		Y:     new(big.Int).SetBytes(yBytes),
	}, nil
}
