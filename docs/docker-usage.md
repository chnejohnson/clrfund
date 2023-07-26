# Docker usage

## Prerequisite

You need to use MACI to generate SNARK params and two corresponding verifier contracts, and place them in the correct locations within this project.

## Get started

Once you have completed the aforementioned steps, you can start a round on this project using docker-compose.

```bash
docker-compose up -d
```

```bash
docker-compose run clrfund yarn start:node
```

Open another terminal, and enter the Docker container to perform the operations.

```bash
docker-compose exec clrfund bash
```

Run the following scripts inside the Docker container.

```bash
cd contracts

yarn deploy:local
yarn deployTestRound:local
yarn contribute:local --no-compile
yarn vote:local --no-compile

yarn timeTravel:local

export NODE_CONFIG='{"snarkParamsPath": "../../../contracts/snark-params/", "zkutil_bin": "/root/.cargo/bin/zkutil"}'

yarn tally:local --no-compile
yarn finalize:local --no-compile
```