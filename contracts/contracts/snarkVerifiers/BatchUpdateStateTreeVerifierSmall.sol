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

contract BatchUpdateStateTreeVerifierSmall {

    using Pairing for *;

    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct VerifyingKey {
        Pairing.G1Point alpha1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[17] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alpha1 = Pairing.G1Point(uint256(18526488245439836938863824036992280511728020499768912146989749476537090375188),uint256(11742694953432459587721716145916183852041183631919521980376742627277067288666));
        vk.beta2 = Pairing.G2Point([uint256(2453318430315855050202519854871413109066238153096130489001305944720926132320),uint256(11911075734749353210699870455012495618892948481941858724749865727604882325763)], [uint256(7174956685608082130233405152589958763876309015600096279738773415665728481724),uint256(2256142145585681163377152783271536283239089794956716813166084836002401856886)]);
        vk.gamma2 = Pairing.G2Point([uint256(7966828129851393696487077561312288114205449952137360130969143448137978673033),uint256(16702673133297141976850464493294444117315240981620140778787850285974659386862)], [uint256(20902638914169658187827306702394678682163942773206803212976202209438672708805),uint256(2694988044360534314384703342969715006512150517672608934506271386379476304877)]);
        vk.delta2 = Pairing.G2Point([uint256(14724118337156957516048231491076650107574468612268068881282901454343738812394),uint256(17563349652947000712878766840572053338796907271337493527433469835216126086918)], [uint256(17119636806160297039573563417959324716419821311778433200914799881960997931604),uint256(4974364667329833857205317292790067477918721736129705635899687792830922344727)]);
        vk.IC[0] = Pairing.G1Point(uint256(604461108621333111301454214794882254314610442447024115533597650130555420940),uint256(16777482131021433671236450615729038269981036866971902445551253144387048983748));
        vk.IC[1] = Pairing.G1Point(uint256(5331311364924142694445300905283895500433766971467858846900470666911089966766),uint256(3337179262497109714171813529311486438579406112011754411042293095848188844465));
        vk.IC[2] = Pairing.G1Point(uint256(19973461216838372913555604339266547463088888177476089926534553611282041308034),uint256(4296795032231636590962083373656514701277549019382354079708768940862171384417));
        vk.IC[3] = Pairing.G1Point(uint256(8835611607294832030438001018537415895348531147319999906259378503755121809401),uint256(19335394648186010915560514359191078312929221093375884465524482996299946439046));
        vk.IC[4] = Pairing.G1Point(uint256(5651448238365722962196478431047472655881261176497500507735925212658618747720),uint256(14238006411758543164858603771189578890739884486785955796538347602901191364460));
        vk.IC[5] = Pairing.G1Point(uint256(15110004338155792448580684112027652211440871860670544628676126853840800606987),uint256(6160111814993072505866430636134112230462383487978518175487351053697497492291));
        vk.IC[6] = Pairing.G1Point(uint256(7932447874729312203410344553248719722939571753772504324879574717920059232319),uint256(4403868381070023207063736213515521240184515123741624863570659021588574573334));
        vk.IC[7] = Pairing.G1Point(uint256(13913943042141415684091657359715878593278890217486089073943638844534463973442),uint256(18549668059390045597594968038120722957462810067477393560749847581626113968021));
        vk.IC[8] = Pairing.G1Point(uint256(5313262043755842101703242143054709705663109877017870906703363247190134821926),uint256(14725970632668013745109404310767287281793625736912322034400958988869339518017));
        vk.IC[9] = Pairing.G1Point(uint256(915547750920232001280137853152747027480375461368423571491182918324884308359),uint256(10053622593198779827097169729611131908858444083066908417355592205953668211617));
        vk.IC[10] = Pairing.G1Point(uint256(4856074062346091261696600798523799550102540942292461515910894115215918583089),uint256(14218858646513015467761946587074860414964991305814002256804186272630978461622));
        vk.IC[11] = Pairing.G1Point(uint256(18987717797096778681739874532912284053154252908196665853688199341205382723651),uint256(2492187360081633881487677036888146518874368623613474614961338242587876629548));
        vk.IC[12] = Pairing.G1Point(uint256(9365190366133593155211175445388754950780721185572404299560289713629169508928),uint256(9184245123029693092698711618603498454901707281215591460830148167800413983117));
        vk.IC[13] = Pairing.G1Point(uint256(3315710577912633197387514775757396778077162462959358101748448570936934152871),uint256(20206602738857857292665267931120528745115317546461057321795399902731422823114));
        vk.IC[14] = Pairing.G1Point(uint256(9585642427032756339648919990224681031836267806560035719203449003005028300437),uint256(9722108749043753177407399917608579473700820881534231513494472196335449142505));
        vk.IC[15] = Pairing.G1Point(uint256(5682677119059579556943104462492492628520243439898549121351308806237452220703),uint256(4908578176809449634053083338477265431285197574449165138579352856772417546328));
        vk.IC[16] = Pairing.G1Point(uint256(8991198807136902925218185335475544314299676439750677585487727481148615446143),uint256(2722800721601067174023976594800950171281004672367003239086066262172878550171));

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
        for (uint256 i = 0; i < 16; i++) {
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
