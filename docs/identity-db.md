# Tables
## identix_accounts
```javascript
// unique user id, primarykey
id: int

// public label to show as user's name. Defaults to primary DID
public_label: string


```
## web3_accounts
```javascript
// web3 account id, primarykey
id: int

// one idx account to many web3 accounts link 
parent_idx_account: int

// non-empty for custodial and non-custodial accounts
public_key: string

// non-empty for custodial account
private_key: string

// cryptowallet address for non-custodial accounts, if available
wallet_address: string

// Blockchain id. TODO: currently 'everscale'; 'polygon' etc in the future
// May alos be used to specify anchoring protocol, like 'everscale_1.4'
blockchain: string

```
## web2_accounts
```javascript
// primarykey
id: int

// one idx account to many web2 accounts link 
parent_idx_account: int

// web2 method, TODO. oauth2 = 1, magic_link = 2 or alike
method: int

// method-specific identifier
accound_id: string
```
## known_dids
```javascript
// primarykey
id: int

// the DID 
did: string

// one idx account to many DIDs link. 
// Must correlate with parent_web3_account. 
// Here for table lookup optimization   
parent_idx_account: int

// one web3 account (custodial controller) to many DIDs, 
// since all DIDs are anchored in a concrete blockchain
parent_web3_account: int
```