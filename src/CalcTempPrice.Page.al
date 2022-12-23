page 50200 "CalcTempPrice"
{
    ApplicationArea = All;
    Caption = 'CalcTempPrice';
    PageType = Card;
    SourceTable = "Calc. Price Buffer";
    UsageCategory = Tasks;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(General)
            {
                field("Price Type"; Rec."Price Type")
                {
                }
                field(CustomerVendorNo; Rec.CustomerVendorNo)
                {
                }
                field("Contact No."; Rec."Contact No.")
                {
                }
                field("Calculation Date"; Rec."Calculation Date")
                {
                    ApplicationArea = All;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                }
                field("Price Asset Type"; Rec."Price Asset Type")
                {
                }
                field("No."; Rec."No.")
                {
                }
                field("Variant Code"; Rec."Variant Code")
                {
                }
                field("Work Type Code"; Rec."Work Type Code")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Unit Of Measure Code"; Rec."Unit Of Measure Code")
                {
                }
                field("Unit Price"; Rec."Unit Price")
                {
                }
                field("Line Discount %"; Rec."Line Discount %")
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Init();
        Rec.Insert();
    end;
}
