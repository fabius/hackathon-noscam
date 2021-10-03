'reach 0.1';

const Part = {
  //addressSeller: Address,
  //addressBuyer: Address,
  price: UInt,
  safetyCommitment: UInt,
  deadline: UInt,
  approvePayout: Fun([], Bool),
  getStatus: Fun([], Null),
};

export const main = Reach.App(() => {
  const B = Participant('Bob', { // Buyer == deployer
    ...Part,
  });
  const A = Participant('Alice', { // Seller
    ...Part,
    acceptConditions: Fun([UInt], Null),
  });
  const P = Participant('Platform', { // in case someone is trying to play unfair
    ...Part
  });
  deploy();

  // b pays for the product + commitment && deploys the contract
  B.only(() => {
    //const addressSellerB = declassify(interact.addressSeller);
    //const addressBuyerB = declassify(interact.addressBuyer);
    const priceB = declassify(interact.price);
    const safetyCommitmentB = declassify(interact.safetyCommitment);
    const deadlineB = declassify(interact.deadline);
  });
  B.publish(/*addressSellerB, addressBuyerB,*/ priceB, safetyCommitmentB, deadlineB)
   .pay(priceB + safetyCommitmentB);
  commit();

  // a pays commitment
  A.only(() => {
    interact.acceptConditions(priceB);
    //const addressSellerA = declassify(interact.addressSeller);
    //const addressBuyerA = declassify(interact.addressBuyer);
    const priceA = declassify(interact.price);
    const safetyCommitmentA = declassify(interact.safetyCommitment);
    const deadlineA = declassify(interact.deadline);
  });
  A.publish(/*addressSellerA, addressBuyerA,*/ priceA, safetyCommitmentA, deadlineA)
       .pay(safetyCommitmentA)
       .timeout(relativeTime(deadlineB), () => closeTo(B, () => null));

  each([A, B], () => {
    interact.getStatus();
  });

  // have both approve the payout
  var bothApproved = false;
  invariant(balance() == priceB + safetyCommitmentB + safetyCommitmentA);
  while ( !bothApproved ) {
    commit();

    A.only(() => {
      const approvalA = declassify(interact.approvePayout());
    });
    A.publish(approvalA)
     .timeout(relativeTime(deadlineB), () => closeTo(P, () => null));
    commit();

    B.only(() => {
      const approvalB = declassify(interact.approvePayout());
    });
    B.publish(approvalB)
     .timeout(relativeTime(deadlineB), () => closeTo(P, () => null));

    bothApproved = approvalA && approvalB;
    continue
  }

  assert(bothApproved);
  transfer(safetyCommitmentA + priceB).to(A);
  transfer(safetyCommitmentB).to(B);
  commit();
});
