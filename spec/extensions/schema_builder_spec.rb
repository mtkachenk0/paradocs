require "spec_helper"
require "paradocs/builders/schema"

RSpec.describe Paradocs::Builders::Schema do
  let(:payload1) {
    {
      tags: 'tag',
      status: 'visible',
      extra_field: "extra",
      price: "100",
      title: "title",
      variants: [
        {
          stock: '10',
          available_if_no_stock: true,
          extra_field: "extra",
          name: 'v1',
          sku: 'ABC'
        },
        {stock: '10', extra_field: ""}
      ]
    }
  }
  let(:payload2) {
    {
     :cardAccounts=>[
       {
         :resourceId=>"3d9a81b3-a47d-4130-8765-a9c0ff861b99",
         :maskedPan=>"525412******3241",
         :currency=>"EUR",
         :name=>"Main",
         :product=>"Basic Credit",
         :status=>"blocked",
         :creditLimit=>{:currency=>"EUR", :amount=>"15000"},
         :balances=>[{
           :balanceType=>"interimBooked",
           :balanceAmount=>{:currency=>"EUR", :amount=>"14355.78"}
         }, {
           :balanceType=>"nonInvoiced",
           :balanceAmount=>{:currency=>"EUR", :amount=>"4175.86"}
         }],
         :_links=>{
           :transactions=>{
             :href=>"/demobank/api/berlingroup/v1/card-accounts/3d9a81b3-a47d-4130-8765-a9c0ff861b99/transactions"
           }
         }
       }
     ]
   }
  }
end
