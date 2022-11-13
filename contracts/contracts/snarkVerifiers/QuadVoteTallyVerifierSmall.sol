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
        vk.alpha1 = Pairing.G1Point(uint256(2683619644825904767542322334738481682946780295572375138439675900870410269349),uint256(13338714385589437691222841028862073684128801556150873913374944252720825028103));
        vk.beta2 = Pairing.G2Point([uint256(7546572555693279045692971340909581086634836300627848449191988752031838069260),uint256(6639098292708172259275666742882101964226610476804022119027805719198357971196)], [uint256(4862990302716294049060514659527833930843399922027825869614595337620439961795),uint256(11150128952697003301399432716206776826224528447694320907280565284116929934048)]);
        vk.gamma2 = Pairing.G2Point([uint256(20153619525119607523535692253086239089486810119980158621777988700021407224874),uint256(8623983414784750464792328729568274114441739567314761862271178074546790408532)], [uint256(14250395252381842787788941953457899918263458471429124702954756575091313369668),uint256(4328572360777989539850409885797343395884755152286424087354992619568847173274)]);
        vk.delta2 = Pairing.G2Point([uint256(9819299762091319428189902533724815512662020038482393306048445214715362402109),uint256(3987176044733188803698490357552725332946257385775015467819564517749971979124)], [uint256(250619395966741452571941553851424866521265892089157622194977900619954659119),uint256(3640362940415986113252121981885426365120121010580910532894945886010871220588)]);
        vk.IC[0] = Pairing.G1Point(uint256(13659729797398455051455473265668637060832113415470044363137696925258824074835),uint256(13245193917016162640499969393802852458262936604511349957770549923512804949041));
        vk.IC[1] = Pairing.G1Point(uint256(2665736989488650000379721934260894781997456503748478363350459388399059695960),uint256(5853140226276083637276881729301119534464611206122762151731970090941113162029));
        vk.IC[2] = Pairing.G1Point(uint256(4616854605632212394299822543534440222943703119221215920496809325641686097329),uint256(18908193164599379447341525478680284381568449406414184276806430854040275393189));
        vk.IC[3] = Pairing.G1Point(uint256(4992741575595429515540987467514355491073535643192224920062337798076547757085),uint256(5441750550467629835525272150682589906804562389223104566132679792417565508916));
        vk.IC[4] = Pairing.G1Point(uint256(95754516587643870056556622156787699460164556661840989947226341189164717837),uint256(4490848417077409382230079573582202596010947878714964572115546061003287102932));
        vk.IC[5] = Pairing.G1Point(uint256(9642357632128364576294509067165127447128287350823338401008190731188034276299),uint256(4659514546721930348663244938784462939310086017046535365486847402446505133368));
        vk.IC[6] = Pairing.G1Point(uint256(3278093444488466302463684725632396894866160792017731682005028416602964144176),uint256(11678571070708524060156758281912480305484905984203837126717256875019344754807));
        vk.IC[7] = Pairing.G1Point(uint256(19828999431007104799233351803798032274937592719412901768846999867811975664624),uint256(10056609064918687446407119788520686562305153984881649398789216316046831606035));
        vk.IC[8] = Pairing.G1Point(uint256(20107986329490094519970965203368022345133670140039708968221477923849523925426),uint256(13601242637754003674023353317050664659612936103120650289449187177713273172344));
        vk.IC[9] = Pairing.G1Point(uint256(14602023139955531348378035183289496525628370290506039344137887513450094004622),uint256(6355226688710374135775465514883898129683601923344631553698261757671936310059));
        vk.IC[10] = Pairing.G1Point(uint256(376071163236293049184153649960834006033489721637418691607961243809376017567),uint256(342200251432051361010860564409149998319464987570792195605071676137974111658));

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
