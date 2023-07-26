// SPDX-License-Identifier: MIT

// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

// 2019 OKIMS

pragma solidity ^0.6.12;

library Pairing {

    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    /*
     * @return The negation of p, i.e. p.plus(p.negate()) should be zero. 
     */
    function negate(G1Point memory p) internal pure returns (G1Point memory) {

        // The prime q in the base field F_q for G1
        if (p.X == 0 && p.Y == 0) {
            return G1Point(0, 0);
        } else {
            return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
        }
    }

    /*
     * @return The sum of two points of G1
     */
    function plus(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {

        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }

        require(success,"pairing-add-failed");
    }

    /*
     * @return The product of a point on G1 and a scalar, i.e.
     *         p == p.scalar_mul(1) and p.plus(p) == p.scalar_mul(2) for all
     *         points p.
     */
    function scalar_mul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {

        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }

    /* @return The result of computing the pairing check
     *         e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
     *         For example,
     *         pairing([P1(), P1().negate()], [P2(), P2()]) should return true.
     */
    function pairing(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {

        G1Point[4] memory p1 = [a1, b1, c1, d1];
        G2Point[4] memory p2 = [a2, b2, c2, d2];

        uint256 inputSize = 24;
        uint256[] memory input = new uint256[](inputSize);

        for (uint256 i = 0; i < 4; i++) {
            uint256 j = i * 6;
            input[j + 0] = p1[i].X;
            input[j + 1] = p1[i].Y;
            input[j + 2] = p2[i].X[0];
            input[j + 3] = p2[i].X[1];
            input[j + 4] = p2[i].Y[0];
            input[j + 5] = p2[i].Y[1];
        }

        uint256[1] memory out;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }

        require(success,"pairing-opcode-failed");

        return out[0] != 0;
    }
}

contract QuadVoteTallyVerifierSmall {

    using Pairing for *;

    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct VerifyingKey {
        Pairing.G1Point alpha1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[11] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alpha1 = Pairing.G1Point(uint256(8023163554561933747527815466549732398124162580292239931515013442924351665346),uint256(21844679050897773882481853450980777974841267682663692018287849902408304801203));
        vk.beta2 = Pairing.G2Point([uint256(15625423375017902463421025463178797676113247491221565856794053425216886354280),uint256(7198960219333518483909265239612322957304033186109509884633181114994679900240)], [uint256(4189277281074260815496814803691328622411004049928944800099517429018619150098),uint256(4659669335039673005139139590405780785693917401478311311253648047429692230190)]);
        vk.gamma2 = Pairing.G2Point([uint256(16287044241316116902681268687870101735279030593561685545254651775495666736703),uint256(11265000574701859919725726984047036617163349183536798856558418417897741622959)], [uint256(1343721786204218851882744429509308449845483883591917973968799576233931273031),uint256(10784338045144640452118976095070435785722126325554172268470282998137116785346)]);
        vk.delta2 = Pairing.G2Point([uint256(14452424699566880820166776356071756414578666305898154042101340413483729432816),uint256(19340813332126760025361289122421786937657984417992526785818507360488573436826)], [uint256(16792262303356517668766459429428579334673700160261247522388416957037830524924),uint256(17674296326388986722005744696022868228991572756302358341327928904117714243280)]);
        vk.IC[0] = Pairing.G1Point(uint256(7016239581167110937058666336168425792766310908327874156504145367704868377789),uint256(14525105803474021905555988208941952267286067409049372092648069731439548974914));
        vk.IC[1] = Pairing.G1Point(uint256(15681790302427164836551834541434436544855797676475306229062156894603689726482),uint256(19574794555577998615093008514288729194759397461410780954191650829536880548586));
        vk.IC[2] = Pairing.G1Point(uint256(9912121426394481810206815533674262672724132062321029913669237569703577953885),uint256(2281590757809342709860617589188591315931826506923773316984448079191567741530));
        vk.IC[3] = Pairing.G1Point(uint256(8366207962187159504670558268928348065714529079307535837399503405655974474178),uint256(7838986596088879434196795262362527296772052347697239694791755130802884265266));
        vk.IC[4] = Pairing.G1Point(uint256(20930344382008304554562352569166517313634139996678857818643716596118493593664),uint256(21777487104123960330223147287341754865556623380634684625525190706581587105097));
        vk.IC[5] = Pairing.G1Point(uint256(20156170892264445944635694659340721842035665165575169610285080539863339053509),uint256(18451379109406758234109888850716095202130610707354437794646622602261153497723));
        vk.IC[6] = Pairing.G1Point(uint256(5017427407050718111601779054818760278234310231491798493221178874409785656252),uint256(6752332949279017011852330431525646723628345140722452543131242440619547944007));
        vk.IC[7] = Pairing.G1Point(uint256(13570171031407367948523048967712922388576637212224108409065221946961330404515),uint256(16096484029622269299751912454937341394268660318003388298537086443279644478523));
        vk.IC[8] = Pairing.G1Point(uint256(17561998288147363020924409536068776234303867067479300259615677274253683619829),uint256(20975697138753733282019654208621507547909723501913320319859545767812813648990));
        vk.IC[9] = Pairing.G1Point(uint256(166409546877765293003391577976391015651505013698960489117629727014692541673),uint256(14598215706324763158332662723637442583581012555144908171168985616922657350886));
        vk.IC[10] = Pairing.G1Point(uint256(9652622778936820587509888888035810584876380877524372026193679116119676842096),uint256(3855402167941943805261510526156219281743625538236941629868065786055464518259));

    }
    
    /*
     * @returns Whether the proof is valid given the hardcoded verifying key
     *          above and the public inputs
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory input
    ) public view returns (bool) {

        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);

        VerifyingKey memory vk = verifyingKey();

        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);

        // Make sure that proof.A, B, and C are each less than the prime q
        require(proof.A.X < PRIME_Q, "verifier-aX-gte-prime-q");
        require(proof.A.Y < PRIME_Q, "verifier-aY-gte-prime-q");

        require(proof.B.X[0] < PRIME_Q, "verifier-bX0-gte-prime-q");
        require(proof.B.Y[0] < PRIME_Q, "verifier-bY0-gte-prime-q");

        require(proof.B.X[1] < PRIME_Q, "verifier-bX1-gte-prime-q");
        require(proof.B.Y[1] < PRIME_Q, "verifier-bY1-gte-prime-q");

        require(proof.C.X < PRIME_Q, "verifier-cX-gte-prime-q");
        require(proof.C.Y < PRIME_Q, "verifier-cY-gte-prime-q");

        // Make sure that every input is less than the snark scalar field
        //for (uint256 i = 0; i < input.length; i++) {
        for (uint256 i = 0; i < 10; i++) {
            require(input[i] < SNARK_SCALAR_FIELD,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.plus(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }

        vk_x = Pairing.plus(vk_x, vk.IC[0]);

        return Pairing.pairing(
            Pairing.negate(proof.A),
            proof.B,
            vk.alpha1,
            vk.beta2,
            vk_x,
            vk.gamma2,
            proof.C,
            vk.delta2
        );
    }
}
