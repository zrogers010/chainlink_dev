from brownie import SimpleStorage, accounts, config

def read_contract():
    print(SimpleStorage[-1])
    simple_storage = SimpleStorage[-1]
    # abi
    # address
    print(simple_storage.retrieve())

def main():
    read_contract()
