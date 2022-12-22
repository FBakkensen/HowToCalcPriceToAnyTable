table 50100 "Calc. Price Buffer"
{
    Caption = 'CalcPrice';
    TableType = Temporary;

    fields
    {
        field(1; "Key"; Code[10])
        {
            Caption = 'Key';
        }
        field(10; "Price Type"; Enum "Price Type")
        {
            Caption = 'Price Type';

            trigger OnValidate()
            begin
                if "Price Type" <> xRec."Price Type" then
                    Validate(CustomerVendorNo, '');
            end;
        }
        field(11; "CustomerVendorNo"; Code[20])
        {
            Caption = 'CustomerVendorNo';
            TableRelation =
            if ("Price Type" = const(Sale)) Customer."No."
            else
            if ("Price Type" = const(Purchase)) Vendor."No.";

            trigger OnValidate()
            begin
                if CustomerVendorNo = '' then begin
                    Validate("Currency Code", '');
                    Validate("Price Calculation Method", "Price Calculation Method"::" ");
                    Validate("Contact No.", '');
                    Validate("Customer Price Group", '');
                    Validate("Customer Disc. Group", '');
                    exit;
                end;

                case "Price Type" of
                    "Price Type"::Sale:
                        UpdateFromCustomer();
                    "Price Type"::Purchase:
                        UpdateFromVendor();
                end;
            end;
        }
        field(12; "Price Calculation Method"; Enum "Price Calculation Method")
        {
            Caption = 'Price Calculation Method';
        }
        field(13; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location.Code;
        }
        field(14; "Customer Price Group"; Code[10])
        {
            Caption = 'Customer Price Group';
            TableRelation = "Customer Price Group";
        }
        field(15; "Customer Disc. Group"; Code[20])
        {
            Caption = 'Customer Disc. Group';
            TableRelation = "Customer Discount Group";
        }
        field(5052; "Contact No."; Code[20])
        {
            Caption = 'Sell-to Contact No.';
            TableRelation = Contact."No.";
        }
        field(20; "Price Asset Type"; Enum "Price Asset Type")
        {
            Caption = 'Price Asset Type';

            trigger OnValidate()
            begin
                if "Price Asset Type" <> xRec."Price Asset Type" then
                    Validate("No.", '');
            end;
        }
        field(21; "No."; Code[20])
        {
            Caption = 'No.';
            TableRelation =
            if ("Price Asset Type" = const(Item)) Item."No."
            else
            if ("Price Asset Type" = const(Resource)) Resource."No."
            else
            if ("Price Asset Type" = const("G/L Account")) "G/L Account"."No."
            else
            if ("Price Asset Type" = const("Item Discount Group")) "Item Discount Group".Code
            else
            if ("Price Asset Type" = const("Resource Group")) "Resource Group"."No."
            else
            if ("Price Asset Type" = const("Service Cost")) "Service Cost".Code;

            trigger OnValidate()
            begin
                if "No." = '' then
                    Validate("Unit Of Measure Code", '');

                case "Price Asset Type" of
                    "Price Asset Type"::Item:
                        UpdateFromItem();
                    "Price Asset Type"::Resource:
                        UpdateFromResource();
                    "Price Asset Type"::"G/L Account":
                        UpdateFromGLAccount();
                    "Price Asset Type"::"Item Discount Group":
                        UpdateFromItemDiscountGroup();
                    "Price Asset Type"::"Resource Group":
                        UpdateFromResourceGroup();
                    "Price Asset Type"::"Service Cost":
                        UpdateFromServiceCost();
                end;
            end;
        }
        field(22; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = if ("Price Asset Type" = const(Item)) "Item Variant".Code where("Item No." = field("No."));
        }
        field(23; "Work Type Code"; Code[10])
        {
            Caption = 'Work Type Code';
            TableRelation = "Work Type";

            trigger OnValidate()
            var
                WorkType: Record "Work Type";
            begin
                case true of
                    "Price Asset Type" <> "Price Asset Type"::Resource,
                    not WorkType.Get("Work Type Code"):
                        exit;
                end;

                Validate("Unit of Measure Code", WorkType."Unit of Measure Code");
            end;
        }
        field(24; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }

        field(100; "Unit Of Measure Code"; Code[10])
        {
            Caption = 'Unit Of Measure Code';
            TableRelation =
            if ("Price Asset Type" = const(Item)) "Item Unit of Measure".Code
            else
            if ("Price Asset Type" = const(Resource)) "Resource Unit of Measure"
            else
            if ("Price Asset Type" = const("Service Cost")) "Unit of Measure".Code;

            trigger OnValidate()
            var
                UnitofMeasureManagement: Codeunit "Unit of Measure Management";
            begin
                SetQtyPerUnitOfMeasure();
            end;
        }

        field(101; "Qty. per Unit of Measure"; Decimal)
        {
            Caption = 'Qty. per Unit of Measure';
            DecimalPlaces = 0 : 5;
            Editable = false;
            InitValue = 1;
        }
        field(200; "Calculation Date"; Date)
        {
            Caption = 'Calculation Date';
        }
        field(300; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency;

            trigger OnValidate()
            begin
                if "Currency Code" = '' then
                    currency.InitRoundingPrecision()
                else
                    Currency.Get("Currency Code");

                UpdateCurrencyFactor()
            end;
        }
        field(310; "Currency Factor"; Decimal)
        {
            Caption = 'Currency Factor';
            DecimalPlaces = 0 : 15;
            Editable = false;
            MinValue = 0;
        }
        field(500; "Line Discount %"; Decimal)
        {
            Caption = 'Line Discount %';
            DecimalPlaces = 0 : 5;
            MaxValue = 100;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidateLineDiscountPercent(true);
            end;
        }
        field(501; "Line Discount Amount"; Decimal)
        {
            AutoFormatExpression = "Currency Code";
            AutoFormatType = 1;
            Caption = 'Line Discount Amount';

            trigger OnValidate()
            begin
                "Line Discount Amount" := Round("Line Discount Amount", Currency."Amount Rounding Precision");

                if xRec."Line Discount Amount" <> "Line Discount Amount" then
                    UpdateLineDiscPct();

                UpdateAmounts();
            end;
        }
        field(502; "Unit Price"; Decimal)
        {
            AutoFormatExpression = "Currency Code";
            AutoFormatType = 2;
            Caption = 'Unit Price';

            trigger OnValidate()
            begin
                Validate("Line Discount %");
            end;
        }
        field(504; "Recalculate Invoice Disc."; Boolean)
        {
            Caption = 'Recalculate Invoice Disc.';
            Editable = false;
        }
        field(505; "Line Amount"; Decimal)
        {
            AutoFormatExpression = "Currency Code";
            AutoFormatType = 1;
            Caption = 'Line Amount';

            trigger OnValidate()
            var
                MaxLineAmount: Decimal;
            begin
                TestField("Price Asset Type");
                TestField(Quantity);
                TestField("Unit Price");

                "Line Amount" := Round("Line Amount", Currency."Amount Rounding Precision");
                MaxLineAmount := Round(Quantity * "Unit Price", Currency."Amount Rounding Precision");
                CheckLineAmount(MaxLineAmount);

                Validate("Line Discount Amount", MaxLineAmount - "Line Amount");
            end;
        }
    }
    keys
    {
        key(PK; "Key")
        {
            Clustered = true;
        }
    }

    procedure UpdateCurrencyFactor()
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        UpdateCurrencyExchangeRates: Codeunit "Update Currency Exchange Rates";
        CurrencyDate: Date;
    begin
        if "Currency Code" = '' then begin
            "Currency Factor" := 0;
            exit;
        end;

        if "Calculation Date" <> 0D then
            CurrencyDate := "Calculation Date"
        else
            CurrencyDate := WorkDate();

        if UpdateCurrencyExchangeRates.ExchangeRatesForCurrencyExist(CurrencyDate, "Currency Code") then
            "Currency Factor" := CurrencyExchangeRate.ExchangeRate(CurrencyDate, "Currency Code")
        else
            UpdateCurrencyExchangeRates.ShowMissingExchangeRatesNotification("Currency Code");
    end;

    local procedure UpdateFromCustomer()
    var
        Customer: Record Customer;
    begin
        case true of
            CustomerVendorNo = '',
            not Customer.Get(CustomerVendorNo):
                exit;
        end;

        Validate("Currency Code", Customer."Currency Code");
        Validate("Price Calculation Method", Customer.GetPriceCalculationMethod());
        Validate("Location Code", Customer."Location Code");
        Validate("Customer Price Group", Customer."Customer Price Group");
        Validate("Customer Disc. Group", '');

        UpdateContactFromCustomer(CustomerVendorNo);
    end;

    local procedure UpdateFromVendor()
    var
        Vendor: Record Vendor;
    begin
        case true of
            CustomerVendorNo = '',
            not Vendor.Get(CustomerVendorNo):
                exit;
        end;

        Validate("Currency Code", Vendor."Currency Code");
        Validate("Price Calculation Method", Vendor.GetPriceCalculationMethod());
        Validate("Location Code", Vendor."Location Code");

        UpdateContactFromVendor(CustomerVendorNo);
    end;

    local procedure UpdateFromItem()
    var
        Item: Record Item;
    begin
        case true of
            "No." = '',
            not Item.Get("No."):
                exit;
        end;

        case "Price Type" of
            "Price Type"::Sale:
                Validate("Unit Of Measure Code", Item."Sales Unit of Measure");
            "Price Type"::Purchase:
                Validate("Unit Of Measure Code", Item."Purch. Unit of Measure");
        end;
    end;

    local procedure UpdateFromResource()
    var
        Resource: Record Resource;
    begin
        case true of
            "No." = '',
            not Resource.Get("No."):
                exit;
        end;

        Validate("Unit Of Measure Code", Resource."Base Unit of Measure");
    end;

    local procedure UpdateFromGLAccount()
    GLAccount: Record "G/L Account";
    begin
        case true of
            "No." = '',
            not GLAccount.Get("No."):
                exit;
        end;
        Validate("Unit Of Measure Code", '');
    end;

    local procedure UpdateFromItemDiscountGroup()
    begin
        Validate("Unit Of Measure Code", '');
    end;

    local procedure UpdateFromResourceGroup()
    begin
        Validate("Unit Of Measure Code", '');
    end;

    local procedure UpdateFromServiceCost()
    var
        ServiceCost: Record "Service Cost";
    begin
        case true of
            "No." = '',
            not ServiceCost.Get("No."):
                exit;
        end;

        Validate("Unit Of Measure Code", ServiceCost."Unit of Measure Code");
    end;

    local procedure SetQtyPerUnitOfMeasure()
    var
        Item: Record Item;
        Resource: Record Resource;
        UnitofMeasureManagement: Codeunit "Unit of Measure Management";
    begin
        case true of
            "Unit Of Measure Code" = '',
            "No." = '':
                begin
                    "Qty. per Unit of Measure" := 1;
                    exit;
                end;
        end;

        case "Price Asset Type" of
            "Price Asset Type"::Item:
                begin
                    Item.Get("No.");
                    "Qty. per Unit of Measure" := UnitofMeasureManagement.GetQtyPerUnitOfMeasure(Item, "Unit Of Measure Code");
                end;
            "Price Asset Type"::Resource:
                begin
                    Resource.Get("No.");
                    "Qty. per Unit of Measure" := UnitofMeasureManagement.GetResQtyPerUnitOfMeasure(Resource, "Unit Of Measure Code");
                end;
            else
                "Qty. per Unit of Measure" := 1;
        end;
    end;

    local procedure ValidateLineDiscountPercent(DropInvoiceDiscountAmount: Boolean)
    begin
        "Line Discount Amount" :=
          Round(
            Round(Quantity * "Unit Price", Currency."Amount Rounding Precision") *
            "Line Discount %" / 100, Currency."Amount Rounding Precision");

        UpdateAmounts();
    end;

    local procedure UpdateLineDiscPct()
    var
        LineDiscountPct: Decimal;
        IsOutOfStandardDiscPctRange: Boolean;
    begin
        if Round(Quantity * "Unit Price", Currency."Amount Rounding Precision") <> 0 then begin
            LineDiscountPct := Round(
                "Line Discount Amount" / Round(Quantity * "Unit Price", Currency."Amount Rounding Precision") * 100,
                0.00001);
            IsOutOfStandardDiscPctRange := not (LineDiscountPct in [0 .. 100]);
            if IsOutOfStandardDiscPctRange then
                Error(LineDiscountPctErr);
            "Line Discount %" := LineDiscountPct;
        end else
            "Line Discount %" := 0;
    end;

    procedure UpdateAmounts()
    var
        LineAmount: Decimal;
    begin
        if "Price Asset Type" = "Price Asset Type"::" " then
            exit;

        "Recalculate Invoice Disc." := true;

        "Line Amount" := Round(Quantity * "Unit Price", Currency."Amount Rounding Precision") - "Line Discount Amount";
    end;

    local procedure CheckLineAmount(MaxLineAmount: Decimal)
    begin
        if "Line Amount" < 0 then
            if "Line Amount" < MaxLineAmount then
                Error(LineAmountInvalidErr);

        if "Line Amount" > 0 then
            if "Line Amount" > MaxLineAmount then
                Error(LineAmountInvalidErr);
    end;

    local procedure UpdateContactFromCustomer(CustomerNo: Code[20])
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        Customer: Record Customer;
        Contact: Record Contact;
        IsHandled: Boolean;
    begin
        if Customer.Get(CustomerNo) then begin
            if Customer."Primary Contact No." <> '' then
                "Contact No." := Customer."Primary Contact No."
            else begin
                ContactBusinessRelation.Reset();
                ContactBusinessRelation.SetCurrentKey("Link to Table", "No.");
                ContactBusinessRelation.SetRange("Link to Table", ContactBusinessRelation."Link to Table"::Customer);
                ContactBusinessRelation.SetRange("No.", CustomerNo);
                if ContactBusinessRelation.FindFirst() then
                    "Contact No." := ContactBusinessRelation."Contact No."
                else
                    "Contact No." := '';
            end;
        end;
    end;

    local procedure UpdateContactFromVendor(VendorNo: Code[20])
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        Customer: Record Customer;
        Contact: Record Contact;
        IsHandled: Boolean;
    begin
        if Customer.Get(VendorNo) then begin
            if Customer."Primary Contact No." <> '' then
                "Contact No." := Customer."Primary Contact No."
            else begin
                ContactBusinessRelation.Reset();
                ContactBusinessRelation.SetCurrentKey("Link to Table", "No.");
                ContactBusinessRelation.SetRange("Link to Table", ContactBusinessRelation."Link to Table"::Vendor);
                ContactBusinessRelation.SetRange("No.", VendorNo);
                if ContactBusinessRelation.FindFirst() then
                    "Contact No." := ContactBusinessRelation."Contact No."
                else
                    "Contact No." := '';
            end;
        end;
    end;

    var
        Currency: Record Currency;
        LineDiscountPctErr: Label 'The value in the Line Discount % field must be between 0 and 100.';
        LineAmountInvalidErr: Label 'You have set the line amount to a value that results in a discount that is not valid. Consider increasing the unit price instead.';


}
