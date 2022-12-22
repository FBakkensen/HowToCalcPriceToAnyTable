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
                if CustomerVendorNo = '' then
                    "Price Calculation Method" := "Price Calculation Method"::" ";

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
        "Price Calculation Method" := Customer.GetPriceCalculationMethod();
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
        "Price Calculation Method" := Vendor.GetPriceCalculationMethod();
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
    begin
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
}
