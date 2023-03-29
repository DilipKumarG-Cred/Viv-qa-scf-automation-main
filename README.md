# Viv-qa-scf-automation
This repo contains SCF UI automation regression suite written on Selenium with Ruby and it's managed by the QA team.

## How to setup:
  * Install Ruby(> 2.3.0)
  * Install Bundler
  * Download ChromeDriver(>= 2.46) and place it under '/usr/local/bin'
  * Clone the repo and get into the parent folder of it in Terminal
  * Run 'bundle install'
  * Install Allure command line tools

 ## How to execute:
  * Get inside the parent folder from Terminal
  * To run all specs sequentially,
     * Run 'rspec <Spec-folder> / <spec_file-name.rb>' (eg: 'rspec Spec/Commercials/Processing_fee_spec.rb')
  * To run parallely,
     * Run 'parallel_rspec -n <no.of browsers> <Spec-folder> / <spec_file-name.rb>' (eg: 'parallel_rspec - n 4 Spec/Commercials/*.rb')

 ## How to generate reports:
  * Wait for the tests gets executed successfully
  * Run 'allure generate Report --clean'
  * Run 'allure serve report' (This will open a reports in your default browser's tab)
  * 'ctrl + c' to kill serving.

# Modules covered
  * Onboarding - Invoice, PO, DD(with and without bank mandate)
  * Onboarding - Vendor, Dealer with Processing fees(approve and reject)
  * Onboarding - Reject docs, Reject vendor
  * Onboarding - Bulk import & validations, Assign to other programs(Invoice, PO and DD)
  * Onboarding - Onboarding Validations, Multiple Promoter, Multiple KM, Existing vendor validations
  * Commercials - Skip Counterparty approvals, Mandate invoice file
  * Transactions - Invoice, PO, DD, GRN based
  * Transactions - As Anchor, Vendor and dealer
  * Transactions - Reject, Re-Inititate, Bulk import & vallidations, Bulk approve & reject
  * Transactions - Overdue transactions
  * PO Transactions - Invoice review approve and Reject
  * Disbursement - Frontend and Rearend strategies
  * Disbursement - Invoice, PO, GRN based
  * Disbursement - Single and Multiple disbursements, Payment history as all parties
  * Repayment - IPC and CIP strategy
  * Repayment - Bullet payment and Partial payment
  * Repayment - Payment on Current due, Overdue, Pre-Payments, Refunds
  * Repayment - Payment for single and multiple transactions
  * Repayment - Payment history and breakdown as all parties
  * DD Settlement 
  * Switch as multiple users


# Tags
 * Tags are used to execute specific specs which matches it. (Eg. --tag <tag_name>) Below are the tags which have been used inside,
   * *scf* -> To run complete regression

# Other available tags and modules covered under each

* onboarding
  - Covers complete Onboarding module

* disbursements
  - Covers complete Disbursement module

* payments
  - Covers complete Payment module
  - DD Resettlement 

* transactions
  - Covers complete transcations(Invoice, PO and DD)

* users
  - Includes switch user verifications

* dd
  - Includes DD transaction and Resettlement

* po
  - Includes PO transaction, disbursements, invoice review

* pf
  - Include processing fee spec alone
