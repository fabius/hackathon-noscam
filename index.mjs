import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
import {ask,yesno,done} from '@reach-sh/stdlib/ask.mjs';
const stdlib = loadStdlib(process.env);

(async () => {
  const isBob = await ask("Are you Bob the buyer? (y/n)", yesno);
  const who = isBob ? "Bob" : "Alice";
  let interactivePrice = null;

  let acc = await stdlib.newTestAccount(stdlib.parseCurrency(1000));
  const getBalance = async () => stdlib.formatCurrency(await stdlib.balanceOf(acc), 4);
  const balanceBefore = await getBalance();
  console.log(`Your balance before is ${balanceBefore}`);

  let ctc = null;
  if (isBob) {
    interactivePrice = await ask("Enter the pricetag of the item you're about to buy: ", stdlib.parseCurrency);
    console.log('Bob deploying contract...');
    ctc = acc.deploy(backend);
    ctc.getInfo().then((info) => {
      console.log(`The contract is deployed as "${JSON.stringify(info)}"`);
    });
  } else {
    interactivePrice = await ask("Enter the pricetag of the item you're about to sell: ", stdlib.parseCurrency);
    const info = await ask("Enter contract information: ", JSON.parse);
    ctc = acc.attach(backend, info);
  }

  let interact = {};
  interact.approvePayout = async () => {
    const accepted = await ask("Do you approve the payout? (y/n)", yesno);
    return accepted;
  };
  interact.getStatus = async () => {
    console.log(`Your current balance is: ${await getBalance()}`);
  };
  if (isBob) {
    await backend.Bob(ctc, {
      //addressSeller: Alice.getAddress(),
      //addressBuyer: Bob.getAddress(),
      ...interact,
      price: interactivePrice,
      safetyCommitment: 1 * interactivePrice,
      deadline: 1000,
    });
  } else {
    await backend.Alice(ctc, {
      //addressSeller: Alice.getAddress(),
      //addressBuyer: Bob.getAddress(),
      ...interact,
      price: interactivePrice,
      safetyCommitment: 1 * interactivePrice,
      deadline: 1000,
      acceptConditions: async (pricetag) => {
	const accepted = await ask(`Do you accept the price and safety commitment of ${stdlib.formatCurrency(pricetag,4)}? (y/n)`, yesno);
	if (!accepted) { process.exit(0); }
      }
    });
  }

  const after = await getBalance();
  console.log(`Your balance is now ${after}`);
  done();
})();
